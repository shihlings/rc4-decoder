`default_nettype none
// state machine to control the internal processes of a single core
module decoder_core_state_machine (clk, reset, core_start, core_finish, s_ram_reset_start, s_ram_reset_finish, shuffle_array_start, shuffle_array_finish, reset_mem_access_controller, decrypt_message_start, decrypt_message_finish, d_ram_check_start, d_ram_check_finish);
    input logic clk, reset, s_ram_reset_finish, shuffle_array_finish, decrypt_message_finish, core_start, d_ram_check_finish;
    output logic s_ram_reset_start, shuffle_array_start, decrypt_message_start, reset_mem_access_controller, core_finish, d_ram_check_start;
    
    assign s_ram_reset_start = state[0];
    assign shuffle_array_start = state[1];
    assign reset_mem_access_controller = state[2];
    assign decrypt_message_start = state[3];
    assign d_ram_check_start = state[4];
    assign core_finish = state[5];

    localparam state_bits = 9;
    logic [state_bits-1:0] state, next_state;

    // dff to store current state of the state machine
    vdff #(.N(state_bits)) core_state_vdff (.d(next_state), 
                                            .clk(clk), 
                                            .rst(reset), 
                                            .q(state));

    // combinational logic to determine the next state of the state machine according to the current state and other inputs
    decoder_core_state_machine_comb_logic #(.state_bits(state_bits)) decoder_core_state_machine_comb_logic_1 (.clk(clk),
                                                                                                              .s_ram_reset_finish(s_ram_reset_finish),
                                                                                                              .shuffle_array_finish(shuffle_array_finish),
                                                                                                              .state(state),
                                                                                                              .next_state(next_state),
                                                                                                              .decrypt_message_finish(decrypt_message_finish),
                                                                                                              .d_ram_check_finish(d_ram_check_finish),
                                                                                                              .core_start(core_start));
endmodule

// cominational logic to determine the next state of the state machine according to the current state and other inputs
module decoder_core_state_machine_comb_logic #(parameter state_bits) (clk, decrypt_message_finish, core_start, s_ram_reset_finish, shuffle_array_finish, d_ram_check_finish, state, next_state);
    input logic clk, s_ram_reset_finish, shuffle_array_finish, decrypt_message_finish, core_start, d_ram_check_finish;
    input logic [state_bits-1:0] state;
    output logic [state_bits-1:0] next_state;
    
    // state = {state_num, core_finish, d_ram_check_start, decrypt_message_start, reset_mem_access_controller, shuffle_array_start, s_ram_reset_start}
    localparam [state_bits-1:0] restart =         'b000_000_100;
    localparam [state_bits-1:0] idle =            'b001_000_000;
    localparam [state_bits-1:0] reset_s_mem =     'b010_000_001;
    localparam [state_bits-1:0] shuffle_array =   'b011_000_010;
    localparam [state_bits-1:0] decrypt_message = 'b100_001_000;
    localparam [state_bits-1:0] check_d_ram =     'b101_010_000;
    localparam [state_bits-1:0] finish =          'b110_100_000;

    always_comb begin
        case (state)
            restart: next_state = idle;
            idle: next_state = core_start ? reset_s_mem : idle;

            // first for loop
            reset_s_mem: next_state = s_ram_reset_finish ? shuffle_array : reset_s_mem;

            // second for loop
            shuffle_array: next_state = shuffle_array_finish ? decrypt_message : shuffle_array;

            // third for loop
            decrypt_message: next_state = decrypt_message_finish ? check_d_ram : decrypt_message;

            // check if d_ram contains valid info (all lowercase or spaces)
            check_d_ram: next_state = d_ram_check_finish ? finish : check_d_ram;
            
            finish: next_state = core_start ? finish : idle;
            default: next_state = restart;
        endcase
    end
endmodule
`default_nettype wire