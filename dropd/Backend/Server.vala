/*
 * Copyright (c) 2011-2015 Drop Developers
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Marcus Wichelmann <marcus.wichelmann@hotmail.de>
 */

public class DropDaemon.Backend.Server : ThreadedSocketService {
    private static const string CERT_PATH = config.PKGDATADIR + "/cert.pem";
    private static const string KEY_PATH = config.PKGDATADIR + "/key.pem";

    public signal void new_transmission_interface_registered (string interface_path);
    public signal void transmission_interface_removed (string interface_path);

    private SettingsManager settings_manager;

    private DBusConnection dbus_connection;

    private TlsCertificate? server_certificate = null;

    private uint transmission_counter = 0;

    public Server (SettingsManager settings_manager) {
        Object (max_threads : -1);

        this.settings_manager = settings_manager;

        Bus.own_name (BusType.SESSION, "org.dropd.IncomingTransmission", BusNameOwnerFlags.NONE, (dbus_connection) => {
            this.dbus_connection = dbus_connection;
        }, null, () => {
            warning ("Could not aquire DBus name org.dropd.IncomingTransmission");
        });

        debug ("Loading certificate from \"%s\"...", config.PKGDATADIR);

        try {
            server_certificate = new TlsCertificate.from_files (CERT_PATH, KEY_PATH);
        } catch (Error e) {
            critical ("Loading server certificate failed: %s", e.message);
        }

        try {
            this.add_inet_port (Application.PORT, new ServerPort (Application.PORT));
            this.add_inet_port (Application.UNENCRYPTED_PORT, new ServerPort (Application.UNENCRYPTED_PORT));
        } catch (Error e) {
            critical ("Registering port %u failed: %s", Application.PORT, e.message);
        }

        connect_signals ();
    }

    private void connect_signals () {
        this.run.connect ((connection, source_object) => {
            ServerPort? current_port = (source_object as ServerPort);

            if (current_port == null) {
                return false;
            }

            bool provide_tls = (current_port.port == Application.PORT);

            try {
                IncomingTransmission protocol_implementation;
                TlsServerConnection? tls_connection = null;

                if (provide_tls) {
                    tls_connection = TlsServerConnection.new (connection, server_certificate);

                    debug ("Initializing new tls connection...");

                    if (tls_connection == null) {
                        warning ("Creating tls connection failed.");

                        return false;
                    }

                    debug ("Handshaking...");

                    if (!tls_connection.handshake ()) {
                        warning ("TLS-Handshake failed.");

                        return false;
                    }

                    debug ("Connection established.");

                    protocol_implementation = new IncomingTransmission (tls_connection, settings_manager.get_display_name (), true);
                } else {
                    protocol_implementation = new IncomingTransmission (connection, settings_manager.get_display_name (), false);
                }

                string interface_path = "/org/dropd/IncomingTransmission%u".printf (transmission_counter++);

                try {
                    uint object_id = dbus_connection.register_object (interface_path, protocol_implementation);

                    new_transmission_interface_registered (interface_path);

                    debug ("DBus interface %s registered.", interface_path);

                    protocol_implementation.state_changed.connect ((state) => {
                        if (state != IncomingTransmission.ServerState.FAILURE &&
                            state != IncomingTransmission.ServerState.REJECTED &&
                            state != IncomingTransmission.ServerState.CANCELED &&
                            state != IncomingTransmission.ServerState.FINISHED) {
                            return;
                        }

                        /* Close connection if possible/necessary */
                        try {
                            if (provide_tls) {
                                tls_connection.close ();
                            } else {
                                connection.close ();
                            }

                            debug ("Connection closed.");
                        } catch {}

                        /* Close DBus interface */
                        dbus_connection.unregister_object (object_id);

                        transmission_interface_removed (interface_path);

                        debug ("DBus interface %s removed.", interface_path);
                    });
                } catch (Error e) {
                    warning ("Registering DBus interface %s failed: %s", interface_path, e.message);
                }
            } catch (Error e) {
                warning ("Creating tls connection failed: %s", e.message);
            }

            return false;
        });
    }
}