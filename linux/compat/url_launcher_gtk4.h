// Temporary GTK4 adapter for url_launcher_linux 3.2.x's GTK3 launch path.
// Remove when upstream supports GTK4; see docs/gtk4.md.
#pragma once

#include <gio/gio.h>
#include <gtk/gtk.h>

#if GTK_MAJOR_VERSION >= 4
static inline GtkWidget *moosh_url_launcher_toplevel(GtkWidget *widget) {
  GtkRoot *root = gtk_widget_get_root(widget);
  return root == nullptr ? nullptr : GTK_WIDGET(root);
}

static inline gboolean moosh_url_launcher_show_uri(GtkWindow *window,
                                                   const gchar *uri,
                                                   guint32 timestamp,
                                                   GError **error) {
  (void)window;
  (void)timestamp;
  // This is the same GIO fallback already used by the upstream plugin when
  // no Flutter view is available. It avoids importing GTK3 into a GTK4 process.
  return g_app_info_launch_default_for_uri(uri, nullptr, error);
}

#define gtk_widget_get_toplevel moosh_url_launcher_toplevel
#define gtk_show_uri_on_window moosh_url_launcher_show_uri
#endif
