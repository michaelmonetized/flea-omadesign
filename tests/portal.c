#include <gio/gio.h>
#include <stdio.h>

static void response(GDBusConnection *connection, const gchar *sender,
                     const gchar *path, const gchar *interface, const gchar *signal,
                     GVariant *parameters, gpointer loop) {
    gchar *answer = g_variant_print(parameters, TRUE);
    printf("%s\n", answer);
    g_free(answer);
    g_main_loop_quit(loop);
}

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    GError *error = NULL;
    GDBusConnection *connection = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (!connection) { fprintf(stderr, "%s\n", error->message); return 1; }
    GVariantBuilder options;
    g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
    g_variant_builder_add(&options, "{sv}", "handle_token", g_variant_new_string("flea_oma_verify"));
    g_variant_builder_add(&options, "{sv}", "modal", g_variant_new_boolean(FALSE));
    g_variant_builder_add(&options, "{sv}", "current_folder",
                         g_variant_new_bytestring(argv[1]));
    GVariant *answer = g_dbus_connection_call_sync(connection,
        "org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.FileChooser", "OpenFile",
        g_variant_new("(ss@a{sv})", "", "Choose an Omadesign file", g_variant_builder_end(&options)),
        G_VARIANT_TYPE("(o)"), G_DBUS_CALL_FLAGS_NONE, 30000, NULL, &error);
    if (!answer) { fprintf(stderr, "%s\n", error->message); return 1; }
    const gchar *request;
    g_variant_get(answer, "(&o)", &request);
    printf("%s\n", request);
    fflush(stdout);
    GMainLoop *loop = g_main_loop_new(NULL, FALSE);
    g_dbus_connection_signal_subscribe(connection, "org.freedesktop.portal.Desktop",
        "org.freedesktop.portal.Request", "Response", request, NULL,
        G_DBUS_SIGNAL_FLAGS_NONE, response, loop, NULL);
    g_main_loop_run(loop);
    g_main_loop_unref(loop);
    g_variant_unref(answer);
    g_object_unref(connection);
    return 0;
}
