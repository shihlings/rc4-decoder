`default_nettype none 
// copies data from one memory to another - must be equal in size
module copy_memory_fsm #(parameter data_width, parameter addr_width) (source_q, source_addr, destination_data, destination_addr, destination_wren, clk, reset, start, finish, access_source_request, access_source_granted, access_destination_request, access_destination_granted);
    input logic [data_width-1:0] source_q;
    input logic start, clk, reset, access_source_granted, access_destination_granted;
    output logic finish, access_source_request, access_destination_request, destination_wren;
    output logic [data_width-1:0] destination_data;
    output logic [addr_width-1:0] source_addr, destination_addr;
    
    // source and destination addresses are the same
    assign destination_addr = current_addr;
    assign source_addr = current_addr;

    // address dff to keep track of current address
    logic [4:0] current_addr, next_addr;
    logic rst_addr, incr_addr;
    assign next_addr = incr_addr ? (current_addr + 5'b1) : current_addr;
    vdff #(.N(5)) addr_dff (.d(next_addr),
                            .rst(rst_addr),
                            .clk(clk),
                            .q(current_addr));

    // directly connect the output of source to input of destination
    assign destination_data = source_q;

    // state dff for state machine
    localparam state_bits = 8;
    logic [state_bits-1:0] state, next_state;
    vdff #(.N(state_bits)) copy_key_sol_state_dff (.d(next_state), 
                                                   .rst(reset), 
                                                   .clk(clk), 
                                                   .q(state));

    assign finish = state[0];
    assign access_source_request = state[1];
    assign access_destination_request = state[1];
    assign destination_wren = state[2];
    assign rst_addr = state[3];
    assign incr_addr = state[4];

    // combinational logic to determine next state
    copy_memory_fsm_comb_logic #(.state_bits(state_bits),
                                 .addr_width(addr_width)) copy_memory_fsm_comb_logic1 (.state(state), 
                                                                                       .next_state(next_state), 
                                                                                       .start(start), 
                                                                                       .access_source_granted(access_source_granted), 
                                                                                       .access_destination_granted(access_destination_granted),
                                                                                       .current_addr(current_addr));
endmodule 

// combinational logic to determin next state machine state
module copy_memory_fsm_comb_logic #(parameter state_bits, parameter addr_width) (state, next_state, start, access_source_granted, access_destination_granted, current_addr);
    input logic [state_bits-1:0] state;
    input logic start, access_source_granted, access_destination_granted;
    input logic [addr_width-1:0] current_addr;
    output logic [state_bits-1:0] next_state;
    
    // state = {state_bits, incr_addr, rst_addr, destination_wren, access_source_request, finish}
    localparam [state_bits-1:0] idle =              'b000_00000;
    localparam [state_bits-1:0] wait_mem_access =   'b001_00010;
    localparam [state_bits-1:0] reset_addr =        'b010_01010;
    localparam [state_bits-1:0] read_data =         'b011_00110;
    localparam [state_bits-1:0] write_data =        'b100_00110;
    localparam [state_bits-1:0] increment_addr =    'b101_10010;
    localparam [state_bits-1:0] finish_copy =       'b110_00001;    

    always_comb begin 
        case(state)
            idle:             next_state = start ? wait_mem_access : idle;

            // wait until all access are granted then reset address
            wait_mem_access:  next_state = (access_source_granted & access_destination_granted) ? reset_addr : wait_mem_access;
            reset_addr:       next_state = read_data;

            // read data from source memory and write to destination memory (take 2 cycles to complete)
            read_data:        next_state = write_data;
            write_data:       next_state = (current_addr == {5{1'b1}}) ? finish_copy : increment_addr;

            // increment address if not complete
            increment_addr:   next_state = read_data;

            // stall until state machine is resetted (reset is implemented in the state dff)
            finish_copy:      next_state = finish_copy;
            
            default:          next_state = idle;
        endcase
    end
endmodule

`default_nettype wire