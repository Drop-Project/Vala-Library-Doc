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

public class DropDaemon.Backend.ServiceProvider : Object {
    private static const string SERVICE_TYPE = "_drop._tcp";

    private static const string SERVICE_FIELD_PROTOCOL_VERSION = "protocol-version";
    private static const string SERVICE_FIELD_PROTOCOL_IMPLEMENTATION = "protocol-implementation";
    private static const string SERVICE_FIELD_UNENCRYPTED_PORT = "unencrypted-port";
    private static const string SERVICE_FIELD_DISPLAY_NAME = "display-name";
    private static const string SERVICE_FIELD_SERVER_ENABLED = "server-enabled";

    public Avahi.Client client { private get; construct; }
    public SettingsManager settings_manager { private get; construct; }

    private Avahi.EntryGroup entry_group;
    private Avahi.EntryGroupService? service = null;

    public ServiceProvider (Avahi.Client client, SettingsManager settings_manager) {
        Object (client : client, settings_manager: settings_manager);

        entry_group = new Avahi.EntryGroup ();

        connect_signals ();
    }

    private void connect_signals () {
        client.state_changed.connect ((state) => {
            switch (state) {
                case Avahi.ClientState.S_RUNNING:
                    try {
                        entry_group.attach (client);
                    } catch (Error e) {
                        critical ("Cannot attach client to entry group: %s", e.message);
                    }

                    break;
            }
        });

        entry_group.state_changed.connect ((state) => {
            switch (state) {
                case Avahi.EntryGroupState.UNCOMMITED:
                    try {
                        service = entry_group.add_service (Environment.get_host_name (), SERVICE_TYPE, Application.PORT);
                        set_service_field (SERVICE_FIELD_PROTOCOL_VERSION, Application.PROTOCOL_VERSION.to_string ());
                        set_service_field (SERVICE_FIELD_PROTOCOL_IMPLEMENTATION, Application.PROTOCOL_IMPLEMENTATION);
                        set_service_field (SERVICE_FIELD_UNENCRYPTED_PORT, Application.UNENCRYPTED_PORT.to_string ());
                        set_service_field (SERVICE_FIELD_DISPLAY_NAME, settings_manager.get_display_name ());
                        set_service_field (SERVICE_FIELD_SERVER_ENABLED, settings_manager.server_enabled.to_string ());
                        entry_group.commit ();
                    } catch (Error e) {
                        critical ("Registering service failed: %s", e.message);
                    }

                    break;
                case Avahi.EntryGroupState.ESTABLISHED:
                    debug ("Drop Service registered.");

                    break;
            }
        });

        settings_manager.notify["server-name"].connect (() => {
            set_service_field (SERVICE_FIELD_DISPLAY_NAME, settings_manager.get_display_name ());
        });

        settings_manager.notify["server-enabled"].connect (() => {
            set_service_field (SERVICE_FIELD_SERVER_ENABLED, settings_manager.server_enabled.to_string ());
        });
    }

    private void set_service_field (string field, string value) {
        if (service == null) {
            return;
        }

        try {
            service.set (field, value);
        } catch (Error e) {
            warning ("Writing to service configuration failed: %s", e.message);
        }
    }
}