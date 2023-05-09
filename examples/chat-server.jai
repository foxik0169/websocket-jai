#load "../module.jai";
#import "OpenSSL";

Chat_Client :: struct {
    user_name: string = "(unnamed)";
}

handle_connect :: (using server: *Websocket_Server(Chat_Client), client: *Client(Chat_Client)) {
    print("Client connected!\n");
}

handle_disconnect :: (using server: *Websocket_Server(Chat_Client), client: *Client(Chat_Client)) {
    print("Client % disconnected!\n", client.data.user_name);
}

handle_message :: (
    using server: *Websocket_Server(Chat_Client),
    client:       *Client(Chat_Client),
    message:      []u8)
{
    msg_string := cast(string)message;

    print("Incomming message: %\n", msg_string);

    if slice(msg_string, 0, 4) == {
        case "NAME";
            if msg_string.count-5 <= 0 return;
            new_name := slice(msg_string, 5, msg_string.count-5);
            client.data.user_name = copy_string(new_name);
            print("Client % is changing his name to %\n", client - clients.data, client.data.user_name);
        case "MESG";
            send_all(server, cast([]u8) sprint("MSGF:%:%", client.data.user_name, slice(msg_string, 5, msg_string.count-5)));
    }
}

main :: () {
    server: Websocket_Server(Chat_Client);

    start_server(*server, .{
        use_ssl   = false,
        key_file  = "chat-server.key",
        cert_file = "chat-server.crt",

        on_connect_callback    = handle_connect,
        on_message_callback    = handle_message,
        on_disconnect_callback = handle_disconnect,
    });
}

