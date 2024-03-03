opt client_output = "../src/shared/zap/Client.luau"
opt server_output = "../src/shared/zap/Server.luau"

type Entity = struct {
    id: u8,
    x: u8,
    y: u8,
    z: u8,
    orientation: u8,
    animation: u8
}

event Booleans = {
    from: Client,
    type: Reliable,
    call: SingleSync,
    data: boolean[0..1000]
}

event Entities = {
    from: Client,
    type: Reliable,
    call: SingleSync,
    data: Entity[0..1000]
}