/*
 * Copyright (c) 2011-2015 Marcus Wichelmann (marcus.wichelmann@hotmail.de)
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
 */

public abstract class dropd.Backend.ProtocolImplementation : Object {
    /* Bidirectional commands */
    protected static const uint8 GLOBAL_COMMAND_PROTOCOL_FAILURE = 1;

    /* Client -> Server */
    protected static const uint8 CLIENT_COMMAND_FILE_REQUEST = 2;

    /* Server -> Client */

    protected InputStream input_stream;
    protected OutputStream output_stream;

    protected ProtocolImplementation (InputStream input_stream, OutputStream output_stream) {
        this.input_stream = input_stream;
        this.output_stream = output_stream;
    }

    protected void send_package (uint8 command, uint8[] data) {
        try {
            uint16 package_length = (uint16)(data.length + 1);

            output_stream.write ({ (uint8)((package_length >> 8) & 0xff), (uint8)(package_length & 0xff), command });
            output_stream.write (data);
        } catch (Error e) {
            warning ("Sending package failed: %s", e.message);
        }
    }

    protected uint8[]? receive_package (uint8 expected_commmand = 0, uint16 expected_length = 0) {
        try{
            uint8[] header = new uint8[2];

            if (input_stream.read (header) != 2) {
                protocol_failure ("Invalid package header.");

                return null;
            }

            uint16 package_length = (header[0] << 8) + header[1];

            if (expected_length > 0 && package_length != expected_length) {
                protocol_failure ("Unexpected package length.");
                package_length = expected_length;
            }

            uint8[] package = new uint8[package_length];

            if (input_stream.read (package) != package_length) {
                protocol_failure ("Invalid package.");

                return null;
            }

            if (package[0] != expected_commmand) {
                protocol_failure ("Unexpected command.");

                return null;
            }

            return package;
        } catch (Error e) {
            warning ("Receiving package failed: %s", e.message);

            return null;
        }
    }

    private void protocol_failure (string message) {
        warning ("Protocol failure: %s", message);
        send_package (GLOBAL_COMMAND_PROTOCOL_FAILURE, message.data);
    }
}