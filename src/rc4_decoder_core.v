`default_nettype none
// Actual logic cores of the RC Decoder
module rc4_decoder_core #(parameter secret_key_length, parameter addr_width, parameter data_width) (clk, reset, secret_key, core_start, core_finish, solution_correct, d_ram_access_request_ext, d_ram_access_granted_ext, d_ram_addr_ext, d_ram_q, e_ram_access_granted_ext, e_ram_access_request_ext, e_ram_addr_ext, e_ram_data_ext, e_ram_wren_ext);
    input logic clk, reset, core_start, d_ram_access_request_ext, e_ram_access_request_ext, e_ram_wren_ext;
    input logic [secret_key_length-1:0] secret_key;
    input logic [addr_width-1:0] d_ram_addr_ext, e_ram_addr_ext;
    input logic [data_width-1:0] e_ram_data_ext;
    output logic core_finish, solution_correct, d_ram_access_granted_ext, e_ram_access_granted_ext;
    output logic [data_width-1:0] d_ram_q;

    // external port has access port 1 to d_ram, all indexes to xxx_arrs are 1
    assign d_ram_access_granted_ext = d_ram_access_granted_arr[1];
    assign d_ram_access_request_arr[1] = d_ram_access_request_ext;
    assign d_ram_addr_arr[1] = d_ram_addr_ext;
    assign d_ram_data_arr[1] = {data_width{1'b0}};
    assign d_ram_wren_arr[1] = 1'b0;

    // external port has access port 1 to e_ram, all indexes to xxx_arrs are 1
    assign e_ram_access_granted_ext = e_ram_access_granted_arr[1];
    assign e_ram_access_request_arr[1] = e_ram_access_request_ext;
    assign e_ram_addr_arr[1] = e_ram_addr_ext;
    assign e_ram_data_arr[1] = e_ram_data_ext;
    assign e_ram_wren_arr[1] = e_ram_wren_ext;

    // master state machine to control the data flow in the decoder core
    decoder_core_state_machine decoder_core_state_machine_1 (.clk(clk),
                                                             .reset(reset),
                                                             .s_ram_reset_start(s_ram_reset_start),
                                                             .s_ram_reset_finish(s_ram_reset_finish),
                                                             .shuffle_array_start(shuffle_array_start),
                                                             .shuffle_array_finish(shuffle_array_finish),
                                                             .reset_mem_access_controller(reset_mem_access_controller),
                                                             .decrypt_message_start(decrypt_message_start),
                                                             .decrypt_message_finish(decrypt_message_finish),
                                                             .core_start(core_start),
                                                             .core_finish(core_finish),
                                                             .d_ram_check_start(d_ram_check_start),
                                                             .d_ram_check_finish(d_ram_check_finish));

    // Instantiate the Working Memory (s_ram)
    // s_ram is 256 words (each word is 8 bits wide)
    localparam s_ram_addr_width = 8;
    logic s_ram_wren;
    logic [s_ram_addr_width-1:0] s_ram_addr;
    logic [data_width-1:0] s_ram_data, s_ram_q;
    s_memory s_ram (.clock(clk),
                    .address(s_ram_addr),
                    .data(s_ram_data),
                    .wren(s_ram_wren),
                    .q(s_ram_q));
        
    // Instantiate the Encrypted Memory (e_ram)
    // s_ram is 32 words (each word is 8 bits wide)
    logic [addr_width-1:0] e_ram_addr;
    logic [data_width-1:0] e_ram_q, e_ram_data;
    logic e_ram_wren;
    encrypted_memory e_ram (.clock(clk),
                            .address(e_ram_addr),
                            .data(e_ram_data),
                            .wren(e_ram_wren),
                            .q(e_ram_q));

    // Instantiate the Decrypted Memory (d_ram)
    // d_ram is 32 words (each word is 8 bits wide)
    logic [addr_width-1:0] d_ram_addr;
    logic [data_width-1:0] d_ram_data;
    logic d_ram_wren;
    decrypted_memory d_ram (.address(d_ram_addr), 
                            .clock(clk), 
                            .data(d_ram_data), 
                            .wren(d_ram_wren), 
                            .q(d_ram_q));

    // a memory access control module to control who has control over the read/write operations of s_ram
    // the s_ram_q port is always accessible for all modules with no side effects
    // access 0 - s ram reset module
    // access 1 - shuffle module
    // access 2 - decrypt module
    localparam num_s_ram_access = 3;
    logic reset_mem_access_controller;
    logic [s_ram_addr_width-1:0] s_ram_addr_arr [num_s_ram_access-1:0];
    logic [data_width-1:0] s_ram_data_arr [num_s_ram_access-1:0];
    logic [num_s_ram_access-1:0] s_ram_wren_arr, s_ram_access_request_arr, s_ram_access_granted_arr;
    mem_access_control #(.num_mem_access(num_s_ram_access),
                         .data_width(data_width),
                         .addr_width(s_ram_addr_width)) s_ram_access_control (.clk(clk),
                                                                              .reset_controller(reset_mem_access_controller),
                                                                              .mem_access_request(s_ram_access_request_arr),
                                                                              .mem_access_granted(s_ram_access_granted_arr),
                                                                              .in_mem_addr(s_ram_addr_arr),
                                                                              .in_mem_data(s_ram_data_arr),
                                                                              .in_mem_wren(s_ram_wren_arr),
                                                                              .out_mem_addr(s_ram_addr),
                                                                              .out_mem_data(s_ram_data),
                                                                              .out_mem_wren(s_ram_wren));
    
    // a memory access control module to control who has control over the read/write operations of d_ram
    // the d_ram_q port is always accessible for all modules with no side effects
    // access 0 - decrypt_message_fsm module
    // access 1 - external port module
    // access 2 - d_ram_check_fsm module
    localparam num_d_ram_access = 3;
    logic [addr_width-1:0] d_ram_addr_arr [num_d_ram_access-1:0];
    logic [data_width-1:0] d_ram_data_arr [num_d_ram_access-1:0];
    logic [num_d_ram_access-1:0] d_ram_wren_arr, d_ram_access_request_arr, d_ram_access_granted_arr;
    mem_access_control #(.num_mem_access(num_d_ram_access),
                         .data_width(data_width),
                         .addr_width(addr_width)) d_ram_access_control (.clk(clk),
                                                                        .reset_controller(reset_mem_access_controller),
                                                                        .mem_access_request(d_ram_access_request_arr),
                                                                        .mem_access_granted(d_ram_access_granted_arr),
                                                                        .in_mem_addr(d_ram_addr_arr),
                                                                        .in_mem_data(d_ram_data_arr),
                                                                        .in_mem_wren(d_ram_wren_arr),
                                                                        .out_mem_addr(d_ram_addr),
                                                                        .out_mem_data(d_ram_data),
                                                                        .out_mem_wren(d_ram_wren));

    // a memory access control module to control who has control over the read/write operations of d_ram
    // the d_ram_q port is always accessible for all modules with no side effects
    // access 0 - decrypt_message_fsm module
    // access 1 - external port module
    localparam num_e_ram_access = 2;
    logic [addr_width-1:0] e_ram_addr_arr [num_e_ram_access-1:0];
    logic [data_width-1:0] e_ram_data_arr [num_e_ram_access-1:0];
    logic [num_e_ram_access-1:0] e_ram_wren_arr, e_ram_access_request_arr, e_ram_access_granted_arr;
    mem_access_control #(.num_mem_access(num_e_ram_access),
                         .data_width(data_width),
                         .addr_width(addr_width)) e_ram_access_control (.clk(clk),
                                                                        .reset_controller(reset_mem_access_controller),
                                                                        .mem_access_request(e_ram_access_request_arr),
                                                                        .mem_access_granted(e_ram_access_granted_arr),
                                                                        .in_mem_addr(e_ram_addr_arr),
                                                                        .in_mem_data(e_ram_data_arr),
                                                                        .in_mem_wren(e_ram_wren_arr),
                                                                        .out_mem_addr(e_ram_addr),
                                                                        .out_mem_data(e_ram_data),
                                                                        .out_mem_wren(e_ram_wren));

    // a memory reset module to reset the s_ram
    // reset module has access port 0 to s_ram, all indexes to xxx_arrs are 0
    logic s_ram_reset_start, s_ram_reset_finish;
    s_ram_rst #(.s_ram_addr_width(s_ram_addr_width),
                .data_width(data_width)) s_ram_rst_controller (.clk(clk), 
                                                               .s_ram_reset_start(s_ram_reset_start), 
                                                               .s_ram_reset_finish(s_ram_reset_finish),
                                                               .s_ram_wren(s_ram_wren_arr[0]),
                                                               .s_ram_addr(s_ram_addr_arr[0]),
                                                               .s_ram_data(s_ram_data_arr[0]),
                                                               .s_ram_access_granted(s_ram_access_granted_arr[0]),
                                                               .s_ram_access_request(s_ram_access_request_arr[0]));

    // generate pseudo random array based on secret key
    // shuffle module has access port 1 to s_ram, all indexes to xxx_arrs are 1
    logic shuffle_array_start, shuffle_array_finish;
    shuffle_array_fsm #(.secret_key_length(secret_key_length),
                        .data_width(data_width),
                        .s_ram_addr_width(s_ram_addr_width)) shuffle_array (.clk(clk),
                                                                            .shuffle_array_start(shuffle_array_start),
                                                                            .shuffle_array_finish(shuffle_array_finish),
                                                                            .secret_key(secret_key),
                                                                            .s_ram_wren(s_ram_wren_arr[1]),
                                                                            .s_ram_addr(s_ram_addr_arr[1]),
                                                                            .s_ram_data(s_ram_data_arr[1]),
                                                                            .s_ram_access_granted(s_ram_access_granted_arr[1]),
                                                                            .s_ram_access_request(s_ram_access_request_arr[1]),
                                                                            .s_ram_q(s_ram_q));
    
    // decrypt message module
    // decrypt module has access port 2 to s_ram, all indexes to xxx_arrs are 2
    // decrypt module has access port 0 to d_ram, all indexes to xxx_arrs are 0
    // decrypt module has access port 0 to e_ram, all indexes to xxx_arrs are 0
    logic decrypt_message_start, decrypt_message_finish;
    assign e_ram_data_arr[0] = {data_width{1'b0}};
    assign e_ram_wren_arr[0] = 1'b0;
    decrypt_message_fsm #(.addr_width(addr_width),
                          .data_width(data_width),
                          .s_ram_addr_width(s_ram_addr_width)) decrypt_message (.clk(clk),
                                                                                .decrypt_message_start(decrypt_message_start),
                                                                                .decrypt_message_finish(decrypt_message_finish),
                                                                                .s_ram_wren(s_ram_wren_arr[2]),
                                                                                .s_ram_addr(s_ram_addr_arr[2]),
                                                                                .s_ram_data(s_ram_data_arr[2]),
                                                                                .s_ram_access_granted(s_ram_access_granted_arr[2]),
                                                                                .s_ram_access_request(s_ram_access_request_arr[2]),
                                                                                .s_ram_q(s_ram_q),
                                                                                .d_ram_access_granted(d_ram_access_granted_arr[0]),
                                                                                .d_ram_access_request(d_ram_access_request_arr[0]),
                                                                                .d_ram_wren(d_ram_wren_arr[0]),
                                                                                .d_ram_addr(d_ram_addr_arr[0]),
                                                                                .d_ram_data(d_ram_data_arr[0]),
                                                                                .e_ram_access_granted(e_ram_access_granted_arr[0]),
                                                                                .e_ram_access_request(e_ram_access_request_arr[0]),
                                                                                .e_ram_addr(e_ram_addr_arr[0]),
                                                                                .e_ram_q(e_ram_q));

    // check if the solution is correct
    // solution module has access port 2 to d_ram, all indexes to xxx_arrs are 2
    assign d_ram_wren_arr[2] = 1'b0;
    assign d_ram_data_arr[2] = {data_width{1'b0}};
    logic d_ram_check_start, d_ram_check_finish;
    d_ram_check_fsm #(.data_width(data_width),
                      .addr_width(addr_width)) check_d_ram (.clk(clk),
                                                            .reset(reset),
                                                            .d_ram_access_request(d_ram_access_request_arr[2]), 
                                                            .d_ram_access_granted(d_ram_access_granted_arr[2]), 
                                                            .solution_correct(solution_correct), 
                                                            .d_ram_addr(d_ram_addr_arr[2]), 
                                                            .d_ram_q(d_ram_q), 
                                                            .d_ram_check_start(d_ram_check_start), 
                                                            .d_ram_check_finish(d_ram_check_finish));
endmodule
`default_nettype wire