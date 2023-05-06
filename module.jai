#import "Basic";
#import "String";
#import "Socket";
#import "Base64_Encode";
#import "Bit_Operations";
#import "OpenSSL";
#import "Flat_Pool";
#import "POSIX";

bind_ipv4 :: (s: Socket, ip: [4]u8, port: u16) -> s32 {
    address: sockaddr_in;
    address.sin_family = AF_INET;
    address.sin_port = htons(port);

    _ip := (ip[3] << 24) & (ip[2] << 16) & (ip[1] << 8) & ip[0];

    #if OS == .WINDOWS {
        address.sin_addr.S_un.S_addr = _ip;
    } else {
        address.sin_addr.s_addr = _ip;
    }

    return bind(s, xx *address, xx size_of(sockaddr_in));
}

listen_socket: Socket;

Queue_Buffer :: struct ($Block_Total_Size: u64 = 4096) {
    Block_Length :: Block_Total_Size - size_of(*Block);

    Block :: struct {
        memory: [Block_Length]u8;
        next:   *Block = null;
    }

    blocks:    *Block;

    read_pos:  u64; // position in the 0 block, to read from
    write_pos: u64; // position in the last block to write at
}

get_last_block :: (buffer: *Queue_Buffer($BLOCK_TOTAL_SIZE)) -> *Queue_Buffer(BLOCK_TOTAL_SIZE).Block {
    block := buffer.blocks;
    while true {
        if block.next == null break;
        block = block.next;
    }
    return block;
}

append :: (buffer: *Queue_Buffer, data: []u8) {
    if buffer.blocks == null
        buffer.blocks = New(buffer.Block);

    last_block := get_last_block(buffer);
    available_in_last_block := buffer.Block_Length - buffer.write_pos;

    if xx data.count < available_in_last_block {
        memcpy(last_block.memory.data + buffer.write_pos, data.data, data.count);
        buffer.write_pos += xx data.count;

        if buffer.write_pos == buffer.Block_Length {
            buffer.write_pos = 0;
            last_block.next = New(buffer.Block);
        }

        return;
    }

    memcpy(last_block.memory.data + buffer.write_pos, data.data, xx available_in_last_block);
    current_input_offset := available_in_last_block;

    if data.count - xx current_input_offset == 0 {
        buffer.write_pos = 0;
        last_block.next = New(buffer.Block);
        return;
    }

    while data.count - xx current_input_offset > 0 {
        new_block := New(buffer.Block);

        written := min(xx data.count - current_input_offset, buffer.Block_Length);
        memcpy(new_block.memory.data, data.data + current_input_offset, xx written);

        current_input_offset += written;

        buffer.write_pos = written % buffer.Block_Length;

        last_block.next = new_block;
        last_block = new_block;
    }
}

count :: inline (buffer: *Queue_Buffer) -> u64 {
    if !buffer.blocks return 0;

    total_length: u64 = 0;

    block := buffer.blocks;
    while block.next {
        total_length += buffer.Block_Length;
        block = block.next;
    }

    total_length += buffer.write_pos;
    total_length -= buffer.read_pos;

    return total_length;
}

to_array :: (buffer: *Queue_Buffer, allocator := context.allocator) -> []u8 {
    if !buffer.blocks return .[];

    length := count(buffer);
    if length == 0 return .[];

    output := NewArray(xx length, u8, allocator = allocator);

    current_offset := 0;
    read_offset := buffer.read_pos;
    block := buffer.blocks;
    while block.next {
        memcpy(output.data + current_offset, block.memory.data + read_offset, block.memory.count);
        current_offset += block.memory.count;

        block = block.next;
        read_offset = 0;
    }

    memcpy(output.data + current_offset, block.memory.data, xx buffer.write_pos);
    return output;
}

peek :: (buffer: *Queue_Buffer, count: u64 = 512) -> []u8 {
    if !buffer.blocks return .[];

    first_block := buffer.blocks;
    last_block  := get_last_block(buffer);

    output_count := min(count, buffer.Block_Length - buffer.read_pos);

    if first_block == last_block
        output_count = buffer.write_pos - buffer.read_pos;

    output: []u8;
    output.data = buffer.blocks.memory.data + buffer.read_pos;
    output.count = xx output_count;

    return output; //array_view(buffer.blocks.memory, xx buffer.read_pos, xx output_count);
}

have_read :: (buffer: *Queue_Buffer, count: u64) {
    buffer.read_pos += count;

    if buffer.read_pos == buffer.Block_Length {
        to_free_block := buffer.blocks;
        buffer.blocks = buffer.blocks.next;

        free(to_free_block);
        buffer.read_pos = 0;

        if buffer.blocks == null
            buffer.write_pos = 0;
    }
}

reset :: (buffer: *Queue_Buffer) {
    block := buffer.blocks;

    while block {
        to_free := block;
        block = block.next;

        free(to_free);
    }

    buffer.write_pos = 0;
    buffer.read_pos  = 0;
    buffer.blocks = null;
}

Client_State :: enum_flags {
    Initial;

    ExpectAndReadFrameHeader;

    ReadHandshake;
    ReadPayload;
}

Frame_Flags :: enum_flags u16 {
    None :: 0;

    Fin  :: 1 << 0;
    Res1 :: 1 << 1;
    Res2 :: 1 << 2;
    Res3 :: 1 << 3;
}

Frame_Opcode :: enum u16 {
    Continuation :: 0x0;
    Text         :: 0x1;
    Binary       :: 0x2;
    Close        :: 0x8;
    Ping         :: 0x9;
    Pong         :: 0xA;
}

Frame :: struct {
    flags:          Frame_Flags;
    opcode:         Frame_Opcode;
    mask_key:       u32;
    payload_length: u64;
}

Client :: struct ($Data_Type: Type) {
    HEADER_MAX_LENGTH :: 12;

    socket_fd: s32;
    state:     Client_State;

    input_buffer: Queue_Buffer;
    output_buffer: Queue_Buffer;

    frame_header: Frame;

    continuation_initial: Frame;
    continuation_payload: [..][]u8;

    // user data...
    data: Data_Type;
}

Websocket_Server :: struct ($Client_Data_Type: Type) {
    Client_Type :: Client(Client_Data_Type);

    clients: [..]Client_Type;
    epoll_fd: s32;

    on_message_callback: #type (*Websocket_Server(Client_Data_Type), *Client(Client_Data_Type), message: []u8);
}

find_free_slot_or_add_client :: (clients: *[..]Client($Data_Type), client: Client(Data_Type)) -> *Client(Data_Type), s64 {
    found_empty := -1;

    for it, index: << clients {
        if it.socket_fd == -1 {
            found_empty = index;
            break;
        }
    }

    if found_empty != -1 {
        (<< clients)[found_empty] = client;
        return *(<< clients)[found_empty], found_empty;
    }

    array_add(clients, client);
    return *(<< clients)[clients.count-1], clients.count-1;
}

send :: (using server: *Websocket_Server($Client_Data_Type), client: *Client(Client_Data_Type), payload: []u8, binary := false) {
    length := payload.count;
    additional_length_size := 0;

    if length < 126 {
        additional_length_size = 0;
    }
    else if length < 65536 {
        length = 126;
        additional_length_size = 2;
    }
    else {
        length = 127;
        additional_length_size = 8;
    }

    opcode := cast(u8) ifx binary then Frame_Opcode.Binary else Frame_Opcode.Text;

    fin_and_opcode: u8 = 0b10000000 | opcode;
    mask_and_length: u8 = cast(u8)(length);

    net_message := NewArray(payload.count + 2 + additional_length_size, u8, allocator = temp);
    net_message[0] = fin_and_opcode;
    net_message[1] = mask_and_length;

    payload_offset := 2;

    if length < 126 {}
    else if length == 126 {
        swapped_length := byte_swap(cast(u16)payload.count);
        value := cast(*u8) *swapped_length;
        memcpy(*net_message[2], value, size_of(u16));
        payload_offset = 4;
    } else if length == 127 {
        swapped_length := byte_swap(payload.count);
        value := cast(*u8) *swapped_length;
        memcpy(*net_message[2], value, size_of(u64));
        payload_offset = 10;
    }

    memcpy(*net_message[payload_offset], payload.data, payload.count);
    append(*client.output_buffer, net_message);

    epoll_ctl(epoll_fd, EPOLL_CTL_MOD, client.socket_fd, *epoll_event.{
        events = xx EPOLLIN | xx EPOLLOUT | xx EPOLLET,
        data = .{ ptr = client }
    });
}

get_frame_payload_length :: (frame: []u8) -> u64 {
    length := cast(u64) (frame[1] - 128);

    if length == {
        case 126;
            length = byte_swap(<< cast(*u16)(frame.data + 2));
        case 127;
            length = byte_swap(<< cast(*u64)(frame.data + 2));
    }

    return length;
}

parse_frame_header :: (frame: []u8) -> Frame {
    output: Frame;

    fin := frame[0] & (0b10000000);
    re1 := frame[0] & (0b01000000);
    re2 := frame[0] & (0b00100000);
    re3 := frame[0] & (0b00010000);

    opcode := frame[0] & 0x0F;

    if (fin) output.flags |= .Fin;
    if (re1) output.flags |= .Res1;
    if (re2) output.flags |= .Res2;
    if (re3) output.flags |= .Res3;

    length := cast(u64) (frame[1] - 128);

    if length < 126 {
        output.mask_key = << (cast(*u32) (frame.data + 2));
    } else if length == 126 {
        output.mask_key = << (cast(*u32) (frame.data + 4));
    } else if length == 127 {
        output.mask_key = << (cast(*u32) (frame.data + 10));
    }

    output.opcode = xx opcode;
    output.payload_length = get_frame_payload_length(frame);

    return output;
}

send_all :: (using server: *Websocket_Server($Client_Data_Type), message: []u8) {
    for * clients
        send(server, it, message);
}

start_server :: (using server: *Websocket_Server($Data_Type)) {
    log("Starting websocket server...");

    socket_init();
    listen_socket = socket(AF_INET, .SOCK_STREAM, .TCP);

    socket_setting: u32 = 1;
    setsockopt(
        listen_socket, SOL_SOCKET, SO_REUSEADDR, *socket_setting, size_of(u32));

    bind_ipv4(listen_socket, .[127, 0, 0, 1], 9000);

    set_blocking(listen_socket, false);
    listen(listen_socket, 32);

    epoll_fd = epoll_create1(0);
    if epoll_fd == -1 {
        log_error("Could not create epoll instance.");
        assert(false);
    }

    defer close(epoll_fd);

    epoll_ctl(epoll_fd, EPOLL_CTL_ADD, listen_socket, *epoll_event.{ events = xx EPOLLIN | xx EPOLLET, data = epoll_data.{ ptr = xx *listen_socket } });

    while true {
        reset_temporary_storage();

        MAX_EVENTS :: 64;
        events: [MAX_EVENTS]epoll_event;

        event_count := epoll_wait(epoll_fd, events.data, MAX_EVENTS, -1);
        if event_count == -1 {
            log_error("Error on epoll_wait...");
            assert(false);
        }

        for 0..event_count-1 {
            event := *events[it];

            if event.events & xx EPOLLOUT == xx EPOLLOUT {
                client := cast(*Client_Type)event.data.ptr;

                while true {
                    write_data := peek(*client.output_buffer, 512);
                    if write_data.count <= 0 break;

                    written := send(client.socket_fd, write_data.data, xx write_data.count, 0);
                    if written == -1 &&
                        (get_last_socket_error() == SOCKET_WOULDBLOCK || get_last_socket_error() == EAGAIN)
                    {
                        break;
                    }

                    have_read(*client.output_buffer, xx written);
                }

                if client.output_buffer.blocks == null ||
                    (client.output_buffer.blocks.next == null && client.output_buffer.write_pos == 0)
                {
                    epoll_ctl(epoll_fd, EPOLL_CTL_MOD, client.socket_fd, *epoll_event.{
                        events = xx EPOLLIN | xx EPOLLET,
                        data = .{ ptr = client }
                    });
                }
            }

            if event.events & xx EPOLLIN == xx EPOLLIN {
                if event.data.ptr == *listen_socket {
                    while true {
                        client := Client_Type.{
                            socket_fd = accept(listen_socket),
                            state = .ReadHandshake,
                        };

                        if client.socket_fd == -1 && get_last_socket_error() == SOCKET_WOULDBLOCK ||
                           client.socket_fd == -1 && get_last_socket_error() == EAGAIN /* posix */
                            break;

                        set_blocking(client.socket_fd, false);

                        client_ptr := find_free_slot_or_add_client(*clients, client);
                        epoll_ctl(epoll_fd, EPOLL_CTL_ADD, client.socket_fd, *epoll_event.{
                            events = xx EPOLLIN | xx EPOLLET,
                            data = .{ ptr = client_ptr }
                        });
                    }
                } else {
                    client := cast(*Client_Type)event.data.ptr;
                    should_continue := true;

                    while should_continue {
                        should_continue = false;
                        if client.state == {
                            case .ReadHandshake;
                                buffer: [1024]u8; // @todo Use global setting for input buffer size.

                                while true {
                                    in_count := recv(client.socket_fd, buffer.data, xx buffer.count, 0);

                                    if in_count == -1 {
                                        if get_last_socket_error() == SOCKET_WOULDBLOCK || get_last_socket_error() == EAGAIN
                                            break;

                                        log_error("error: in_count was -1 with error %\n", get_last_socket_error());
                                        break;
                                    } else if in_count == 0 {
                                        // @todo Hard disconnect
                                        break;
                                    }

                                    append(*client.input_buffer, array_view(buffer, 0, in_count));
                                }

                                complete_request := to_array(*client.input_buffer, allocator = temp);

                                if cast(string) array_view(complete_request, complete_request.count-4, 4) == "\r\n\r\n" {
                                    if cast(string) array_view(complete_request, 0, 3) != "GET" {
                                        log_error("Invalid request: not a GET request.\n");
                                        assert(false, "This needs to be turned into disconnection.");
                                    }

                                    client_key := "";
                                    has_client_key := false;

                                    headers := array_view(split(cast(string)complete_request, "\r\n"), 1);
                                    for headers {
                                        key_value := split(it, ": ");

                                        if key_value[0] == "Sec-WebSocket-Key" {
                                            client_key = key_value[1];
                                            has_client_key = true;
                                            break;
                                        }
                                    }

                                    if !has_client_key {
                                        log_error("Invalid request: client did not send Sec-WebSocket-Key header.");
                                        assert(false, "This needs to be turned into disconnection.");
                                    }

                                    MAGIC_STRING :: "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

                                    response_format := #string END
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: %

END;

                                    builder: String_Builder;
                                    builder.allocator = temp;

                                    append(*builder, client_key);
                                    append(*builder, MAGIC_STRING);

                                    accept_key_sha: [20]u8;
                                    accept_key_format := builder_to_string(*builder);

                                    SHA1(to_c_string(accept_key_format), xx accept_key_format.count, *accept_key_sha[0]);

                                    accept_key := base64_encode(to_string(accept_key_sha));
                                    response := tprint(response_format, accept_key);

                                    append(*client.output_buffer, cast([]u8)response);

                                    epoll_ctl(epoll_fd, EPOLL_CTL_MOD, client.socket_fd, *epoll_event.{
                                        events = xx EPOLLIN | xx EPOLLOUT | xx EPOLLET,
                                        data = .{ ptr = client }
                                    });

                                    log("Client connected, index: %...\n", client - clients.data);
                                    reset(*client.input_buffer);

                                    client.state = .ExpectAndReadFrameHeader;
                                }

                            case .ExpectAndReadFrameHeader;
                                buffer_count := count(*client.input_buffer);

                                if buffer_count < 6 {
                                    buffer: [6]u8;
                                    in_count := recv(client.socket_fd, buffer.data, cast(u64) (6 - buffer_count), 0);

                                    if in_count == -1 {
                                        if get_last_socket_error() == SOCKET_WOULDBLOCK || get_last_socket_error() == EAGAIN
                                            continue;

                                        log_error("Error: recv returned -1 with error %\n", get_last_socket_error());
                                        continue;
                                    } else if in_count == 0 {
                                        should_continue = true;
                                        continue; // hard disconnect
                                    }

                                    append(*client.input_buffer, array_view(buffer, 0, in_count));
                                    buffer_count = count(*client.input_buffer);
                                }

                                if buffer_count >= 6 {
                                    buffer_content := to_array(*client.input_buffer, allocator = temp);
                                    length := cast(u64) buffer_content[1] - 128;

                                    expected_length := 6;

                                    if length == {
                                        case 126; expected_length += 2;
                                        case 127; expected_length += 8;
                                    }

                                    if expected_length != xx buffer_count {
                                        buffer: [8]u8;
                                        in_count := recv(client.socket_fd, buffer.data, cast(u64) expected_length - buffer_count, 0);

                                        if in_count == -1 {
                                            if get_last_socket_error() == SOCKET_WOULDBLOCK || get_last_socket_error() == EAGAIN
                                                continue;

                                            log_error("Error: recv returned -1 with error %\n", get_last_socket_error());
                                            continue;
                                        } else if in_count == 0 {
                                            should_continue = true;
                                            continue; // hard disconnection
                                        }

                                        append(*client.input_buffer, array_view(buffer, 0, in_count));
                                        buffer_count = count(*client.input_buffer);
                                    }
                                }

                                if buffer_count >= 6 {
                                    frame := to_array(*client.input_buffer, allocator = temp);

                                    length := cast(u64) (frame[1] - 128);
                                    expected_length := 6;

                                    if length == {
                                        case 126; expected_length += 2;
                                        case 127; expected_length += 8;
                                    }

                                    if buffer_count >= xx expected_length {
                                        mask := frame[1] & (0b10000000);

                                        if !mask {
                                            log("Client % tried to send unmasked frame, disconnecting.", client - clients.data);
                                            epoll_ctl(epoll_fd, EPOLL_CTL_DEL, client.socket_fd, null);
                                            close(client.socket_fd);
                                            client.socket_fd = -1;
                                            continue;
                                        }

                                        client.frame_header = parse_frame_header(frame);

                                        if client.frame_header.opcode == .Close {
                                            log("Client % disconnecting.", client - clients.data);
                                            epoll_ctl(epoll_fd, EPOLL_CTL_DEL, client.socket_fd, null);
                                            close(client.socket_fd);
                                            client.socket_fd = -1;
                                            continue;
                                        }

                                        if (client.frame_header.flags & .Fin) != .Fin && client.frame_header.opcode != .Continuation {
                                            client.continuation_initial = client.frame_header;
                                        }

                                        reset(*client.input_buffer);
                                        client.state = .ReadPayload;

                                        epoll_ctl(epoll_fd, EPOLL_CTL_MOD, client.socket_fd, *epoll_event.{
                                            events = xx EPOLLIN | xx EPOLLET,
                                            data = .{ ptr = client }
                                        });
                                    }
                                }

                            case .ReadPayload;
                                already_read := count(*client.input_buffer);

                                while true {
                                    buffer: [client.input_buffer.Block_Length]u8;
                                    in_count := recv(
                                        client.socket_fd,
                                        buffer.data,
                                        min(cast(u64) buffer.count, client.frame_header.payload_length - xx already_read),
                                        0);

                                    if in_count == -1 {
                                        if get_last_socket_error() == SOCKET_WOULDBLOCK || get_last_socket_error() == EAGAIN
                                            break;

                                        log_error("Error: recv returned -1 with error %\n", get_last_socket_error());
                                        break;
                                    } else if in_count == 0 {
                                        // hard disconnect
                                        should_continue = true;
                                        break;
                                    }

                                    append(*client.input_buffer, array_view(buffer, 0, in_count));
                                    already_read += xx in_count;
                                }

                                if already_read == xx client.frame_header.payload_length {
                                    payload := to_array(*client.input_buffer, allocator = temp);
                                    masking_key_view := cast(*u8) *client.frame_header.mask_key;

                                    // @todo choose allocator based on if it's fragmented or not so we don't need to copy
                                    decoded_payload := NewArray(payload.count, u8, allocator = temp);
                                    for it, index: payload
                                        decoded_payload[index] = (it ^ masking_key_view[index % 4]);

                                    if !(client.frame_header.flags & .Fin) {
                                        array_add(*client.continuation_payload, array_copy(decoded_payload));
                                    } else {
                                        if client.frame_header.opcode == .Continuation {
                                            array_add(*client.continuation_payload, array_copy(decoded_payload));

                                            total_length := 0;

                                            for client.continuation_payload
                                                total_length += it.count;

                                            whole_message := NewArray(total_length, u8, allocator = temp);
                                            current_offset := 0;

                                            for client.continuation_payload {
                                                memcpy(whole_message.data + current_offset, it.data, it.count);
                                                current_offset += it.count;
                                            }

                                            on_message_callback(server, client, whole_message);

                                            for client.continuation_payload
                                                array_free(it);

                                            array_reset(*client.continuation_payload);
                                        } else on_message_callback(server, client, decoded_payload);
                                    }

                                    client.state = .ExpectAndReadFrameHeader;
                                    reset(*client.input_buffer);
                                }
                        }
                    }
                }
            }
        }
    }
}

