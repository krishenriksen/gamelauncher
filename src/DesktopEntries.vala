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
* Authored by: Juan Pablo Lozano <libredeb@gmail.com>
* Modified by: Kris Henriksen <krishenriksen.work@gmail.com>
*/

namespace LightPad.Backend {

    public class DesktopEntries : GLib.Object {
    
        private static Gee.ArrayList<GMenu.TreeDirectory> get_categories () {
            var tree = new GMenu.Tree ("applications.menu", GMenu.TreeFlags.INCLUDE_EXCLUDED);
            try {
                // Initialize the tree
                tree.load_sync ();
            } catch (GLib.Error e) {
                error ("Initialization of the GMenu.Tree failed: %s", e.message);
            }
            var root = tree.get_root_directory ();
            var main_directory_entries = new Gee.ArrayList<GMenu.TreeDirectory> ();
            var iter = root.iter ();
            var item = iter.next ();
            while (item != GMenu.TreeItemType.INVALID) {            
                if (item == GMenu.TreeItemType.DIRECTORY) {
                    main_directory_entries.add ((GMenu.TreeDirectory) iter.get_directory ());
                }
                item = iter.next ();
            }

            message ("Number of categories: %d", main_directory_entries.size);
            return main_directory_entries;
        }
        
        private static Gee.HashSet<GMenu.TreeEntry> get_applications_for_category (
            GMenu.TreeDirectory category) {
            
            var entries = new Gee.HashSet<GMenu.TreeEntry>  (
                (x) => ((GMenu.TreeEntry)x).get_desktop_file_path ().hash (),
                (x,y) => ((GMenu.TreeEntry)x).get_desktop_file_path ().hash () == ((GMenu.TreeEntry)y).get_desktop_file_path ().hash ());

            var iter = category.iter ();
            var item = iter.next ();
            while ( item != GMenu.TreeItemType.INVALID) {
            	if (category.get_name () == "Games") {
	                entries.add ((GMenu.TreeEntry) iter.get_entry ());
	            }

	            item = iter.next ();
            }

            message ("Category [%s] has [%d] apps", category.get_name (), entries.size);
            return entries;
        }
        
        public static void enumerate_apps (int icon_size, out Gee.ArrayList<Gee.HashMap<string, string>> list) {
            
            var the_apps = new Gee.HashSet<GMenu.TreeEntry> (
                (x) => ((GMenu.TreeEntry)x).get_desktop_file_path ().hash (),
                (x,y) => ((GMenu.TreeEntry)x).get_desktop_file_path ().hash () == ((GMenu.TreeEntry)y).get_desktop_file_path ().hash ());
            var all_categories = get_categories ();

            foreach (GMenu.TreeDirectory directory in all_categories) {
                var this_category_apps = get_applications_for_category (directory);
                foreach(GMenu.TreeEntry this_app in this_category_apps){
                    the_apps.add(this_app);
                }
            }

            message ("Amount of apps: %d", the_apps.size);
            
            var icon_theme = Gtk.IconTheme.get_default();
            list = new Gee.ArrayList<Gee.HashMap<string, string>> ();
            
            foreach (GMenu.TreeEntry entry in the_apps) {
                var app = entry.get_app_info ();
                if (app.get_nodisplay () == false && 
                    app.get_is_hidden() == false && 
                    app.get_icon() != null)
                {
                    var app_to_add = new Gee.HashMap<string, string> ();
                    app_to_add["name"] = app.get_display_name ();
                    app_to_add["description"] = app.get_description ();
                    
                    // Needed to check further later if terminal is open in terminal (like VIM, HTop, etc.)
                    if (app.get_string ("Terminal") == "true") {
                        app_to_add["terminal"] = "true";
                    }
                    app_to_add["command"] = app.get_commandline ();
                    app_to_add["icon"] = app.get_icon ().to_string ();
                    app_to_add["desktop_file"] = entry.get_desktop_file_path ();

                    list.add (app_to_add);
                }
            }

            // search for exe files in Games and Applications folders
            enumerate_paths(list, icon_size, icon_theme, GLib.Environment.get_variable ("HOME"));
        }

	    public static void enumerate_paths (Gee.ArrayList<Gee.HashMap<string, string>> list, int icon_size, Gtk.IconTheme icon_theme, string directory) {
	        try {
	            Dir dir = Dir.open (directory, 0);
	            string? name = null;
	            bool add = true;

	            while ((name = dir.read_name ()) != null) {
	                string path = Path.build_filename (directory, name);

	                // don't search hidden directories
	                if (name.substring(0, 1) != "." && name.substring(0, 1) != "..") {
	                	
	                	if (name.rstr_len(name.length, ".").ascii_down() == ".exe") {

	                		add = true;

	                		// add only one directory entry, even if more .exe files
		                	foreach (Gee.HashMap<string, string> app in list) {
		                		if (app["name"] == directory.rstr_len(directory.length, "/").replace("/", "")) {
		                			add = false;
		                			break;
		                		}
		                	}

			                if (add == true && FileUtils.test (path, FileTest.IS_REGULAR) && FileUtils.test (path, FileTest.IS_EXECUTABLE)) {
			                	var app_to_add = new Gee.HashMap<string, string> ();
			                    app_to_add["name"] = directory.rstr_len(directory.length, "/").replace("/", "");
			                    app_to_add["description"] = "Windows Executable";
			                    app_to_add["terminal"] = "true";
			                    app_to_add["command"] = directory;
			                    app_to_add["icon"] = "wine";
				                app_to_add["desktop_file"] = "";

			                    list.add (app_to_add);
			                }

			                add = false;
			            }

						if (add == true && FileUtils.test (path, FileTest.IS_DIR)) {
							enumerate_paths(list, icon_size, icon_theme, directory + "/" + name);
	                	}			            
	                }
	            }
	        } catch (FileError e) {
	            warning(e.message);
	        }
	    }

		public static void enumerate_exe (Gee.ArrayList<Gee.HashMap<string, string>> exes, string directory) {
	        try {
	            Dir dir = Dir.open (directory, 0);
	            string? name = null;

	            while ((name = dir.read_name ()) != null) {
	                string path = Path.build_filename (directory, name);

	                // don't search hidden directories
	                if (name.substring(0, 1) != "." && name.substring(0, 1) != "..") {
	                	// only .exe files
	                	if (name.rstr_len(name.length, ".").ascii_down() == ".exe") {
			                if (FileUtils.test (path, FileTest.IS_REGULAR) && FileUtils.test (path, FileTest.IS_EXECUTABLE)) {
			                	var app_to_add = new Gee.HashMap<string, string> ();
			                    app_to_add["name"] = name;
			                    app_to_add["description"] = "Windows Executable";
			                    app_to_add["terminal"] = "true";
			                    app_to_add["command"] = path;

			                    app_to_add["icon"] = search_for_image(directory);
				                app_to_add["desktop_file"] = "";

			                    exes.add (app_to_add);
			                }
			            }
	                }
	            }
	        } catch (FileError e) {
	            warning(e.message);
	        }
	    }

		public static string search_for_image (string directory) {
	        try {
	            Dir dir = Dir.open (directory, 0);
	            string? name = null;

	            while ((name = dir.read_name ()) != null) {
	                // don't search hidden directories
	                if (name.substring(0, 1) != "." && name.substring(0, 1) != "..") {
	                	if (name.rstr_len(name.length, ".").ascii_down() == ".png") {
			               return directory + "/" + name;
			            }
			            else if (name.rstr_len(name.length, ".").ascii_down() == ".jpeg") {
			               return directory + "/" + name;
			            }
			            else if (name.rstr_len(name.length, ".").ascii_down() == ".bmp") {
			               return directory + "/" + name;
			            }
	                }
	            }
	        } catch (FileError e) {
	            warning(e.message);
	        }

	        return "wine";
	    }	    
    }
}