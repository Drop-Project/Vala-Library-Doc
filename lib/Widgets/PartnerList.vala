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

/**
 * This widget displays a list of the available transmission partners.
 */
public class Drop.Widgets.PartnerList : Gtk.Frame {
    /**
     * The session the widget uses to communicate with drop-daemon.
     */
    public Session session { get; construct; }

    /**
     * Sets wether the own server should be shown in the list.
     */
    public bool show_myself { get; construct; }

    private Gee.HashMap<string, PartnerListEntry> entries { get; private set; }

    private Gtk.ScrolledWindow scrolled_window;
    private Gtk.Box entry_list;

    /**
     * Is called when the entry list changed. This could be caused by added/removed rows, changed selections
     * or modified encryption configurations.
     */
    public signal void entries_changed ();

    /**
     * Creates a new list of transmission partners.
     *
     * @param session The session for communicating with drop-daemon.
     * @param show_myself Wether the own server should be shown in the list.
     */
    public PartnerList (Session session, bool show_myself = false) {
        Object (session: session, show_myself: show_myself);

        entries = new Gee.HashMap<string, PartnerListEntry> ();

        build_ui ();
        list_transmission_partners ();
        connect_signals ();
    }

    /**
     * Returns the rows of the list.
     *
     * @return A read-only view of the shown rows.
     */
    public Map<string, PartnerListEntry> get_entries () {
        return entries.read_only_view;
    }

    private void build_ui () {
        this.set_size_request (-1, 100);

        scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled_window.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;

        entry_list = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        entry_list.margin = 12;

        scrolled_window.add (entry_list);

        this.add (scrolled_window);
    }

    private void list_transmission_partners () {
        try {
            foreach (TransmissionPartner transmission_partner in session.get_transmission_partners (show_myself)) {
                add_transmission_partner (transmission_partner);
                add_transmission_partner (transmission_partner);
                add_transmission_partner (transmission_partner);
                add_transmission_partner (transmission_partner);
                add_transmission_partner (transmission_partner);
                add_transmission_partner (transmission_partner);
                add_transmission_partner (transmission_partner);
                add_transmission_partner (transmission_partner);
                add_transmission_partner (transmission_partner);
                add_transmission_partner (transmission_partner);
                add_transmission_partner (transmission_partner);
            }
        } catch (Error e) {
            warning ("Listing tranmission partners failed: %s", e.message);
        }
    }

    private void connect_signals () {
        session.transmission_partner_added.connect (add_transmission_partner);
        session.transmission_partner_removed.connect (remove_transmission_partner);
    }

    private void add_transmission_partner (TransmissionPartner transmission_partner) {
        if (!transmission_partner.server_enabled || (transmission_partner.port == 0 && transmission_partner.unencrypted_port == 0)) {
            return;
        }

        PartnerListEntry entry = new PartnerListEntry (transmission_partner);
        entry.selection_toggled.connect (() => {
            entries_changed ();
        });
        entry.use_encryption_toggled.connect (() => {
            entries_changed ();
        });

        entry_list.pack_start (entry, false, false);
        entries.@set (transmission_partner.name, entry);

        entries_changed ();
    }

    private void remove_transmission_partner (string name) {
        if (!entries.has_key (name)) {
            return;
        }

        PartnerListEntry entry = entries.@get (name);

        entry_list.remove (entry);
        entries.unset (name);

        entries_changed ();
    }
}