`default_nettype none
// Message decryption module
// Decrypts the message given the shuffled array
// start finish protocol used with decrypt_message_start and decrypt_message_finish
module decrypt_message_fsm #(parameter data_width, parameter addr_width, parameter s_ram_addr_width) (clk, decrypt_message_start, decrypt_message_finish, s_ram_wren, s_ram_addr, s_ram_data, s_ram_access_granted, s_ram_access_request, s_ram_q, d_ram_access_granted, d_ram_access_request, d_ram_addr, d_ram_data, d_ram_wren, e_ram_addr, e_ram_q, e_ram_access_granted, e_ram_access_request);
    input logic [data_width-1:0] s_ram_q, e_ram_q;
    input logic clk, decrypt_message_start, s_ram_access_granted, d_ram_access_granted, e_ram_access_granted;
    output logic decrypt_message_finish, s_ram_wren, s_ram_access_request, d_ram_access_request, e_ram_access_request, d_ram_wren;
    output logic [s_ram_addr_width-1:0] s_ram_addr;
    output logic [data_width-1:0] s_ram_data, d_ram_data;
    output logic [addr_width-1:0] d_ram_addr, e_ram_addr;

    // currently there is only one core using the d_ram and e_ram, so we can hardcode the values
    assign d_ram_wren = store_mem_k;
    assign d_ram_addr = index_k;
    assign e_ram_addr = index_k;
    assign d_ram_data = mem_f_data ^ e_ram_q;

    // wires required for the state machine to work 
    logic [s_ram_addr_width-1:0] index_i, index_j, next_index_i, next_index_j;
    logic [data_width-1:0] mem_i_data, mem_j_data, mem_f_data, in_mem_j_data, in_mem_i_data, in_mem_f_data;
    logic [addr_width-1:0] index_k, next_index_k;
    logic reset_index, retrieve_mem_i, retrieve_mem_j, retrieve_mem_f, store_j, store_mem_i, store_mem_j, store_mem_k, increment_i, increment_k_i;
    
    // instantiate the dffs to store the index values
    vdff #(.N(s_ram_addr_width)) index_i_dff (.clk(clk), .rst(reset_index), .d(next_index_i), .q(index_i));
    vdff #(.N(s_ram_addr_width)) index_j_dff (.clk(clk), .rst(reset_index), .d(next_index_j), .q(index_j));
    vdff #(.N(addr_width)) index_k_dff (.clk(clk), .rst(reset_index), .d(next_index_k), .q(index_k));

    // instantiate the dffs to store the memory values
    vdff #(.N(data_width)) mem_s_j_dff (.clk(clk), .rst(1'b0), .d(in_mem_j_data), .q(mem_j_data));
    vdff #(.N(data_width)) mem_s_i_dff (.clk(clk), .rst(1'b0), .d(in_mem_i_data), .q(mem_i_data));
    vdff #(.N(data_width)) mem_s_f_dff (.clk(clk), .rst(1'b0), .d(in_mem_f_data), .q(mem_f_data));

    // define state
    localparam state_bits = 17;
    logic [state_bits-1:0] state, next_state;

    // assign state bits
    assign s_ram_access_request = state[0];
    assign d_ram_access_request = state[0];
    assign e_ram_access_request = state[0];
    assign s_ram_wren = state[1];
    assign reset_index = state[2];
    assign retrieve_mem_i = state[3];
    assign retrieve_mem_j = state[4];
    assign retrieve_mem_f = state[5];
    assign store_j = state[6];
    assign store_mem_i = state[7];
    assign store_mem_j = state[8];
    assign store_mem_k = state[9];
    assign increment_i = state[10];
    assign increment_k_i = state[11];
    assign decrypt_message_finish = state[12];

    // instantiate the state machine output processor
    decrypt_message_arithmetic_process #(.data_width(data_width),
                                         .addr_width(addr_width),
                                         .s_ram_addr_width(s_ram_addr_width)) decrypt_message_arithmetic_process_1 (.index_i(index_i), 
                                                                                                                    .index_j(index_j), 
                                                                                                                    .index_k(index_k),
                                                                                                                    .mem_f_data(mem_f_data), 
                                                                                                                    .mem_i_data(mem_i_data), 
                                                                                                                    .mem_j_data(mem_j_data), 
                                                                                                                    .s_ram_q(s_ram_q), 
                                                                                                                    .increment_i(increment_i), 
                                                                                                                    .increment_k_i(increment_k_i), 
                                                                                                                    .store_j(store_j), 
                                                                                                                    .retrieve_mem_f(retrieve_mem_f), 
                                                                                                                    .retrieve_mem_i(retrieve_mem_i), 
                                                                                                                    .retrieve_mem_j(retrieve_mem_j), 
                                                                                                                    .store_mem_i(store_mem_i), 
                                                                                                                    .store_mem_j(store_mem_j), 
                                                                                                                    .s_ram_wren(s_ram_wren), 
                                                                                                                    .s_ram_addr(s_ram_addr), 
                                                                                                                    .s_ram_data(s_ram_data), 
                                                                                                                    .in_mem_f_data(in_mem_f_data), 
                                                                                                                    .in_mem_i_data(in_mem_i_data), 
                                                                                                                    .in_mem_j_data(in_mem_j_data), 
                                                                                                                    .next_index_i(next_index_i), 
                                                                                                                    .next_index_j(next_index_j), 
                                                                                                                    .next_index_k(next_index_k));

    // instantiate dff to store the state
    vdff #(.N(state_bits)) state_dff (.clk(clk), .rst(1'b0), .d(next_state), .q(state));

    // instantiate the state machine logic to calculate the next state
    decrypt_message_state_comb_logic #(.state_bits(state_bits),
                                       .addr_width(addr_width)) decrypt_message_state_comb_logic_1 (.state(state), 
                                                                                                    .next_state(next_state), 
                                                                                                    .decrypt_message_start(decrypt_message_start), 
                                                                                                    .s_ram_access_granted(s_ram_access_granted),
                                                                                                    .d_ram_access_granted(d_ram_access_granted),
                                                                                                    .e_ram_access_granted(e_ram_access_granted),
                                                                                                    .index_k(index_k));
endmodule

// state machine combinational logic to determine the next state
module decrypt_message_state_comb_logic #(parameter state_bits, parameter addr_width) (state, next_state, decrypt_message_start, s_ram_access_granted, d_ram_access_granted, e_ram_access_granted, index_k);
    input logic [addr_width-1:0] index_k;
    input logic [state_bits-1:0] state;
    input logic decrypt_message_start, s_ram_access_granted, d_ram_access_granted, e_ram_access_granted;
    output logic [state_bits-1:0] next_state;

    // state = {state_num, decrypt_message_finish, increment_k_i, increment_i, store_mem_k, store_mem_j, store_mem_i, store_j, retrieve_mem_f, retrieve_mem_j, retrieve_mem_i, reset_index, s_ram_wren, s & d_ram_access_request}
    localparam [state_bits-1:0] idle =                  'b0000_0_0000_0000_0000;
    localparam [state_bits-1:0] request_mem_access =    'b0001_0_0000_0000_0001;
    localparam [state_bits-1:0] reset_index =           'b0010_0_0000_0000_0101;
    localparam [state_bits-1:0] increment_i =           'b0011_0_0100_0000_0001;
    localparam [state_bits-1:0] retrieve_s_mem_at_i =   'b0100_0_0000_0000_1001;
    localparam [state_bits-1:0] read_i_wait =           'b0101_0_0000_0000_1001;
    localparam [state_bits-1:0] add_and_store_j =       'b0110_0_0000_0100_0001;
    localparam [state_bits-1:0] retrieve_s_mem_at_j =   'b0111_0_0000_0001_0001;
    localparam [state_bits-1:0] read_j_wait =           'b1000_0_0000_0001_0001;
    localparam [state_bits-1:0] store_mem_j_to_i =      'b1001_0_0000_1000_0011;
    localparam [state_bits-1:0] store_mem_i_to_j =      'b1010_0_0001_0000_0011;
    localparam [state_bits-1:0] retreive_s_mem_at_f =   'b1011_0_0000_0010_0001;
    localparam [state_bits-1:0] read_f_wait =           'b1100_0_0000_0010_0001;
    localparam [state_bits-1:0] store_decryted_to_k =   'b1101_0_0010_0000_0001;
    localparam [state_bits-1:0] increment_k_i =         'b1110_0_1000_0000_0001;
    localparam [state_bits-1:0] finish =                'b1111_1_0000_0000_0000;

    always_comb begin
        case (state)
            // if start is asserted, request memory access
            idle:                   next_state = decrypt_message_start ? request_mem_access : idle;

            // if memory access is granted, reset the index
            request_mem_access: begin
                                    if (s_ram_access_granted & d_ram_access_granted & e_ram_access_granted)
                                        next_state = reset_index;
                                    else
                                        next_state = request_mem_access;
                                end
            reset_index:            next_state = increment_i;

            // i = i + 1
            increment_i:            next_state = retrieve_s_mem_at_i;

            // retrieve s[i]
            retrieve_s_mem_at_i:    next_state = read_i_wait;
            read_i_wait:            next_state = add_and_store_j;

            // j = j + s[i]
            add_and_store_j:        next_state = retrieve_s_mem_at_j;

            // retrieve s[j]
            retrieve_s_mem_at_j:    next_state = read_j_wait;
            read_j_wait:            next_state = store_mem_j_to_i;

            // swap s[i] and s[j]
            store_mem_j_to_i:       next_state = store_mem_i_to_j;
            store_mem_i_to_j:       next_state = retreive_s_mem_at_f;

            // f = s[ s[i] + s[j] ]
            retreive_s_mem_at_f:    next_state = read_f_wait;
            read_f_wait:            next_state = store_decryted_to_k;

            // d[k] = f ^ e[k]
            store_decryted_to_k:    next_state = (index_k == {addr_width{1'b1}}) ? finish : increment_k_i;

            // k = k + 1
            increment_k_i:          next_state = retrieve_s_mem_at_i;

            // done
            finish:                 next_state = decrypt_message_start ? finish : idle;
            default:                next_state = idle;
        endcase
    end
endmodule

// contains the combinational logic required to process the state machine bits and the outputs
module decrypt_message_arithmetic_process #(parameter data_width, parameter addr_width, parameter s_ram_addr_width) (increment_i, increment_k_i, store_j, retrieve_mem_f, retrieve_mem_i, retrieve_mem_j, store_mem_i, store_mem_j, s_ram_wren, index_k, mem_f_data, mem_i_data, mem_j_data, index_i, index_j, s_ram_q, next_index_k, s_ram_addr, s_ram_data, next_index_i, next_index_j, in_mem_f_data, in_mem_i_data, in_mem_j_data);
    input logic increment_i, increment_k_i, store_j, retrieve_mem_f, retrieve_mem_i, retrieve_mem_j, store_mem_i, store_mem_j, s_ram_wren;
    input logic [addr_width-1:0] index_k;
    input logic [data_width-1:0] mem_f_data, mem_i_data, mem_j_data, s_ram_q;
    input logic [s_ram_addr_width-1:0] index_i, index_j;
    output logic [addr_width-1:0] next_index_k;
    output logic [s_ram_addr_width-1:0] s_ram_addr, next_index_i, next_index_j;
    output logic [data_width-1:0] s_ram_data, in_mem_f_data, in_mem_i_data, in_mem_j_data;

    always_comb begin
        // if increment_i or increment_k_i is asserted, increment the index
        if (increment_i | increment_k_i)
            next_index_i = index_i + {{s_ram_addr_width-1{1'b0}}, 1'b1}; // i = i + 1
        else
            next_index_i = index_i;

        // if increment_k_i is asserted, increment the index
        if (increment_k_i)
            next_index_k = index_k + {{addr_width-1{1'b0}}, 1'b1}; // k = k + 1
        else
            next_index_k = index_k;

        // if store_j is asserted, store the value of index_j + mem_i_data in index_j
        if (store_j)
            next_index_j = index_j + mem_i_data; // j = j + s[i]
        else
            next_index_j = index_j;
        
        // if retrieve_mem_f is asserted, store the value of s_ram_q in mem_f_data
        if (retrieve_mem_f)
            in_mem_f_data = s_ram_q; // f = s[ s[i] + s[j] ]
        else   
            in_mem_f_data = mem_f_data;

        // if retrieve_mem_j is asserted, store the value of s_ram_q in mem_j_data
        if (retrieve_mem_j)
            in_mem_j_data = s_ram_q; // s[j]
        else   
            in_mem_j_data = mem_j_data;

        // if retrieve_mem_i is asserted, store the value of s_ram_q in mem_i_data
        if (retrieve_mem_i)
            in_mem_i_data = s_ram_q; // s[i]
        else
            in_mem_i_data = mem_i_data;
        
        // s_ram_access_control
        // wren enables writing
        case ({s_ram_wren, store_mem_i, store_mem_j, retrieve_mem_f, retrieve_mem_j, retrieve_mem_i})
            // store s[j] to s[i]
            6'b1_10_000: begin
                s_ram_addr = index_i;
                s_ram_data = mem_j_data;
            end
            
            // store s[i] to s[j]
            6'b1_01_000: begin
                s_ram_addr = index_j;
                s_ram_data = mem_i_data;
            end

            // retrieve f[ s[i] + s[j] ]
            6'b0_00_100: begin
                s_ram_addr = mem_i_data + mem_j_data;
                s_ram_data = {data_width{1'bx}};
            end

            // retrieve s[j]
            6'b0_00_010: begin
                s_ram_addr = index_j;
                s_ram_data = {data_width{1'bx}};
            end

            // retrieve s[i]
            6'b0_00_001: begin
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