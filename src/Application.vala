/*
* Copyright (c) 2011-2020 GameLauncher
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
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Kris Henriksen <krishenriksen.work@gmail.com>
*/

using Gtk;

public class GameLauncherWindow : Window {
    private Box right_box;

    private Gee.ArrayList<Gee.HashMap<string, string>> apps = new Gee.ArrayList<Gee.HashMap<string, string>> ();
    private Gee.ArrayList<Gee.HashMap<string, string>> filtered = new Gee.ArrayList<Gee.HashMap<string, string>> ();

    public GameLauncherWindow () {
        this.set_title ("GameLauncher");
        this.set_skip_pager_hint (true);
        this.set_visual (this.get_screen ().get_rgba_visual ());
        this.set_type_hint (Gdk.WindowTypeHint.NORMAL);
        this.window_position = WindowPosition.CENTER;
        this.resizable = false;
        this.set_default_size (800, 600);

        // Get all apps
        LightPad.Backend.DesktopEntries.enumerate_apps (24, out this.apps);
        this.apps.sort ((a, b) => GLib.strcmp (a["name"], b["name"]));

		var grid = new Grid();

	    var left_box = new Box (Orientation.VERTICAL, 0);

	    /* add apps to left box */
	    foreach (Gee.HashMap<string, string> app in this.apps) {
			var appsbar = new Toolbar ();
			appsbar.get_style_context ().add_class("gamelauncher_appsbar");

			var icon = new Gtk.Image.from_icon_name(app["icon"], IconSize.MENU);
	    	var app_button = new Gtk.ToolButton(icon, app["name"]);
	    	app_button.is_important = true;
			app_button.clicked.connect ( () => {
				if (app["desktop_file"] == "") {
					this.find_exe(app["command"]);
				}
				else {
					// launch .desktop file
			        try {
			            if (app["terminal"] == "true") {
							GLib.AppInfo.create_from_commandline(app["command"], null, GLib.AppInfoCreateFlags.NEEDS_TERMINAL).launch (null, null);
			            } else {
			                new GLib.DesktopAppInfo.from_filename (app["desktop_file"]).launch (null, null);
			            }
			        } catch (GLib.Error e) {
			            warning ("Could not load application: %s", e.message);
			        }
				}
			});

			appsbar.add(app_button);

			left_box.add(appsbar);
		}

		var left_scroll = new ScrolledWindow (null, null);
		left_scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		left_scroll.get_style_context ().add_class("gamelauncher_left_scroll");
		left_scroll.add(left_box);

	    this.right_box = new Box (Orientation.VERTICAL, 0);
	    this.right_box.get_style_context().add_class ("gamelauncher_right_box");

		var right_scroll = new ScrolledWindow (null, null);
		right_scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		right_scroll.get_style_context ().add_class("gamelauncher_right_scroll");
		right_scroll.add(this.right_box);			    

	    grid.add(left_scroll);
	    grid.add(right_scroll);

	    this.add(grid);

        this.draw.connect (this.draw_background);
    }

    private void find_exe(string directory) {
		// clear right box
		GLib.List<weak Gtk.Widget> left_children = this.right_box.get_children ();
		foreach (Gtk.Widget left_element in left_children) {
			this.right_box.remove(left_element);
		}

    	var exes = new Gee.ArrayList<Gee.HashMap<string, string>> ();

        LightPad.Backend.DesktopEntries.enumerate_exe (exes, directory);

        exes.sort ((a, b) => GLib.strcmp (a["name"], b["name"]));

    	foreach (Gee.HashMap<string, string> app in exes) {
	   		var exe_box = new Box (Orientation.HORIZONTAL, 0);

			var app_image = new Image();
			app_image.get_style_context().add_class ("app_image");

			try {
			    app_image.set_from_icon_name(app["icon"], IconSize.LARGE_TOOLBAR);
			} catch {
				warning ("Could not load icon");
			}

			try {
				var pixbuf = new Gdk.Pixbuf.from_file_at_scale (app["icon"], -1, 24, true);
				app_image.set_from_pixbuf(pixbuf);
			} catch (Error e) {
				warning ("Could not load image: %s", e.message);
			}

	        var app_command = new Button ();
	        app_command.label = app["name"];
			app_command.clicked.connect ( () => {

				string command = app["command"].replace(" ", "\\ ");

				message(command);

				try {
		            GLib.AppInfo.create_from_commandline(command, null, GLib.AppInfoCreateFlags.NEEDS_TERMINAL).launch (null, null);
		        } catch (GLib.Error e) {
		            warning ("Could not load application: %s", e.message);
		        }
			});

			exe_box.add(app_image);
			exe_box.add(app_command);

			this.right_box.add(exe_box);
    	}
    }

    private bool draw_background (Gtk.Widget widget, Cairo.Context ctx) {
        widget.get_style_context().add_class ("gamelauncher");
        this.show_all();

        return false;
    } 
}

static int main (string[] args) {
    Gtk.init (ref args);

    string css_file = Config.PACKAGE_SHAREDIR +
        "/" + Config.PROJECT_NAME +
        "/" + "gamelauncher.css";
    var css_provider = new Gtk.CssProvider ();

    try {
        css_provider.load_from_path (css_file);
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
    } catch (GLib.Error e) {
        warning ("Could not load CSS file: %s", css_file);
    }

	var window = new GameLauncherWindow ();

	window.destroy.connect(Gtk.main_quit);
	window.show();

    Gtk.main ();
    return 0;
}
