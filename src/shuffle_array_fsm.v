`default_nettype none
// Pseudo random array shuffling module
// Shuffles the array given a secret key to decrypt a message
// start finish protocol used with shuffle_array_start and shuffle_array_finish
module shuffle_array_fsm #(parameter secret_key_length, parameter data_width, parameter s_ram_addr_width) (clk, shuffle_array_start, shuffle_array_finish, secret_key, s_ram_wren, s_ram_addr, s_ram_data, s_ram_access_granted, s_ram_access_request, s_ram_q);
    input logic [data_width-1:0] s_ram_q;
    input logic [secret_key_length-1:0] secret_key;
    input logic clk, shuffle_array_start, s_ram_access_granted;
    output logic shuffle_array_finish, s_ram_wren, s_ram_access_request;
    output logic [s_ram_addr_width-1:0] s_ram_addr;
    output logic [data_width-1:0] s_ram_data;

    // wires required for the state machine to work 
    logic [s_ram_addr_width-1:0] index_i, index_j, next_index_i, next_index_j;
    logic [data_width-1:0] mem_i_data, mem_j_data, in_mem_i_data, in_mem_j_data, secret_key_selected;
    logic reset_index, increment_i, store_j, store_mem_i, store_mem_j, retrieve_mem_i, retrieve_mem_j;

    // logic to determine which part of the secret key to use
    logic [1:0] secret_key_index;
    assign secret_key_index = index_i % 3;

    // instantiate the dffs to store the index values
    vdff #(.N(s_ram_addr_width)) index_i_dff (.clk(clk), .rst(reset_index), .d(next_index_i), .q(index_i));
    vdff #(.N(s_ram_addr_width)) index_j_dff (.clk(clk), .rst(reset_index), .d(next_index_j), .q(index_j));

    // instantiate the dffs to store the memory values
    vdff #(.N(data_width)) mem_s_j_dff (.clk(clk), .rst(1'b0), .d(in_mem_j_data), .q(mem_j_data));
    vdff #(.N(data_width)) mem_s_i_dff (.clk(clk), .rst(1'b0), .d(in_mem_i_data), .q(mem_i_data));

    // define state
    localparam state_bits = 14;
    logic [state_bits-1:0] state, next_state;

    // assign state bits
    assign store_mem_i = state[0];
    assign store_mem_j = state[1];
    assign s_ram_wren = state[2];
    assign s_ram_access_request = state[3];
    assign store_j = state[4];
    assign increment_i = state[5];
    assign reset_index = state[6];
    assign shuffle_array_finish = state[7];
    assign retrieve_mem_j = state[8];
    assign retrieve_mem_i = state[9];
    
    // instantiate the state machine output processor
    shuffle_array_arithmetic_process #(.s_ram_addr_width(s_ram_addr_width),
                                       .data_width(data_width),
                                       .secret_key_length(secret_key_length)) shuffle_array_arithmetic_process_1 (.s_ram_wren(s_ram_wren), 
                                                                                                                  .store_mem_i(store_mem_i),
                                                                                                                  .store_mem_j(store_mem_j), 
                                                                                                                  .s_ram_q(s_ram_q), 
                                                                                                                  .index_i(index_i), 
                                                                                                                  .index_j(index_j), 
                                                                                                                  .mem_i_data(mem_i_data), 
                                                                                                                  .mem_j_data(mem_j_data), 
                                                                                                                  .secret_key_selected(secret_key_selected), 
                                                                                                                  .next_index_i(next_index_i), 
                                                                                                                  .next_index_j(next_index_j), 
                                                                                                                  .in_mem_i_data(in_mem_i_data), 
                                                                                                                  .in_mem_j_data(in_mem_j_data), 
                                                                                                                  .s_ram_addr(s_ram_addr), 
                                                                                                                  .s_ram_data(s_ram_data), 
                                                                                                                  .secret_key_index(secret_key_index), 
                                                                                                                  .secret_key(secret_key), 
                                                                                                                  .increment_i(increment_i), 
                                                                                                                  .store_j(store_j), 
                                                                                                                  .retrieve_mem_i(retrieve_mem_i), 
                                                                                                                  .retrieve_mem_j(retrieve_mem_j));

    // instantiate dff to store the state
    vdff #(.N(state_bits)) shuffle_state_dff (.clk(clk), .rst(1'b0), .d(next_state), .q(state));

    // instantiate the state machine logic to calculate the next state
    shuffle_state_comb_logic #(.state_bits(state_bits),
                               .s_ram_addr_width(s_ram_addr_width)) shuffle_state_comb_logic_1 (.state(state),
                                                                                                .next_state(next_state),
                                                                                                .s_ram_access_granted(s_ram_access_granted),
                                                                                                .shuffle_array_start(shuffle_array_start),
                                                                                                .index_i(index_i));
endmodule

// comb logic to determine the next state of the state machine
module shuffle_state_comb_logic #(parameter state_bits, parameter s_ram_addr_width) (state, next_state, s_ram_access_granted, shuffle_array_start, index_i);
    input logic [state_bits-1:0] state;
    input logic [s_ram_addr_width-1:0] index_i;
    input logic s_ram_access_granted, shuffle_array_start;
    output logic [state_bits-1:0] next_state;

    // state = {state_num, retrieve_mem_i, retrieve_mem_j, shuffle_array_finish, reset_index, increment_i, store_j, s_ram_access_request, s_ram_wren, store_mem_j, store_mem_i}
    localparam [state_bits-1:0] idle =                  'b0000_00_0000_0000;
    localparam [state_bits-1:0] request_mem_access =    'b0001_00_0000_1000;
    localparam [state_bits-1:0] reset_index =           'b0010_00_0100_1000;
    localparam [state_bits-1:0] retrieve_s_mem_at_i =   'b0011_10_0000_1000;
    localparam [state_bits-1:0] read_i_wait =           'b0100_10_0000_1000;
    localparam [state_bits-1:0] add_and_store_j =       'b0101_00_0001_1000;
    localparam [state_bits-1:0] retrieve_s_mem_at_j =   'b0110_01_0000_1000;
    localparam [state_bits-1:0] read_j_wait =           'b0111_01_0000_1000;
    localparam [state_bits-1:0] store_mem_j_to_i =      'b1000_00_0000_1101;
    localparam [state_bits-1:0] store_mem_i_to_j =      'b1001_00_0000_1110;
    localparam [state_bits-1:0] increment_i =           'b1010_00_0010_1000;
    localparam [state_bits-1:0] finish =                'b1011_00_1000_0000;

    always_comb begin
        case (state)
            // if start is asserted, request memory access
            idle:                   next_state = shuffle_array_start ? request_mem_access : idle;

            // if memory access is granted, reset index
            request_mem_access:     next_state = s_ram_access_granted ? reset_index : request_mem_access;
            reset_index:            next_state = retrieve_s_mem_at_i;

            // retrieve s[i] from memory
            retrieve_s_mem_at_i:    next_state = read_i_wait;
            read_i_wait:            next_state = add_and_store_j;

            // j = j + s[i] + secret_key[i % key_length]
            add_and_store_j:        next_state = retrieve_s_mem_at_j;

            // retrieve s[j] from memory
            retrieve_s_mem_at_j:    next_state = read_j_wait;
            read_j_wait:            next_state = store_mem_j_to_i;

            // swap s[i] and s[j]
            store_mem_j_to_i:       next_state = store_mem_i_to_j;
            store_mem_i_to_j:       next_state = (index_i == {s_ram_addr_width{1'b1}}) ? finish : increment_i;

            // i = i + 1
            increment_i:            next_state = retrieve_s_mem_at_i;

            // finish
            finish:                 next_state = shuffle_array_start ? finish : idle;
            default:                next_state = idle;
        endcase
    end
endmodule

// contains the combinational logic required to process the state machine bits and the outputs
module shuffle_array_arithmetic_process #(parameter s_ram_addr_width, parameter data_width, parameter secret_key_length) (s_ram_wren, store_mem_i, store_mem_j, s_ram_q, index_i, index_j, mem_i_data, mem_j_data, secret_key_selected, next_index_i, next_index_j, in_mem_i_data, in_mem_j_data, s_ram_addr, s_ram_data, secret_key_index, secret_key, increment_i, store_j, retrieve_mem_i, retrieve_mem_j);
    input logic [data_width-1:0] s_ram_q, mem_i_data, mem_j_data;
    input logic [s_ram_addr_width-1:0] index_i, index_j;
    input logic increment_i, store_j, s_ram_wren, store_mem_i, store_mem_j, retrieve_mem_i, retrieve_mem_j;
    input logic [secret_key_length-1:0] secret_key;
    input logic [1:0] secret_key_index;
    output logic [s_ram_addr_width-1:0] next_index_i, next_index_j, s_ram_addr;
    output logic [data_width-1:0] in_mem_i_data, in_mem_j_data, s_ram_data, secret_key_selected;

    always_comb begin
        case (secret_key_index)
            2'b10: secret_key_selected = secret_key[7:0];
            2'b01: secret_key_selected = secret_key[15:8];
            2'b00: secret_key_selected = secret_key[23:16];
            default: secret_key_selected = {8{1'bx}};
        endcase

        // if increment_i is asserted, increment i by 1
        if (increment_i)
            next_index_i = index_i + {{s_ram_addr_width-1{1'b0}}, 1'b1};
        else
            next_index_i = index_i;

        // if store_j is asserted, store j + s[i] + secret_key[i % key_length]
        if (store_j)
            next_index_j = index_j + secret_key_selected + mem_i_data; // j = j + s[i] + secret_key[i % key_length]
        else
            next_index_j = index_j;

        // if retrieve_mem_j is asserted, store the value of s_ram_q in mem_j_data
        if (retrieve_mem_j)
            in_mem_j_data = s_ram_q;
        else   
            in_mem_j_data = mem_j_data;

        // if retrieve_mem_i is asserted, store the value of s_ram_q in mem_i_data
        if (retrieve_mem_i)
            in_mem_i_data = s_ram_q;
        else
            in_mem_i_data = mem_i_data;
    
        // assign the s_ram_addr and s_ram_data based on the state
        case ({s_ram_wren, store_mem_i, store_mem_j, retrieve_mem_i, retrieve_mem_j})
            // store s[i] to s[j]
            5'b1_01_00: begin
                s_ram_addr = index_j;
                s_ram_data = mem_i_data;
            end

            // store s[j] to s[i]
            5'b1_10_00: begin
                s_ram_addr = index_i;
                s_ram_data = mem_j_data;
            end

            // retrieve s[j] from memory
            5'b0_00_01: begin
                s_ram_addr = index_j;
                s_ram_data = {data_width{1'bx}};
            end

            // retrieve s[i] from memory
            5'b0_00_10: begin
                s_ram_addr = index_i;
                s_ram_data = {data_width{1'bx}};
            end
            
            default: begin
                s_ram_addr = {s_ram_addr_width{1'bx}};
                s_ram_data = {data_width{1'bx}};
            end
        endcase
    end
endmodule
`default_nettype wire