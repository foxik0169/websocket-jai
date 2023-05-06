#load "../module.jai";

Chat_Client :: struct {
    user_name: string;
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
            client.data.user_name = copy_string(slice(msg_string, 5, msg_string.count-5));
            print("Client % is changing his name to %\n", client - clients.data, client.data.user_name);
        case "MESG";
            send_all(server, cast([]u8) sprint("MSGF:%:%", client.data.user_name, slice(msg_string, 5, msg_string.count-5)));
    }
}

main :: () {
    server := Websocket_Server(Chat_Client).{};
    server.on_message_callback = handle_message;

    start_server(*server);
}

