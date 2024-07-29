`default_nettype none
// Memory reset module
// Fills all memory locations with the value of its address
// start finish protocol used with s_ram_reset_start and s_ram_reset_finish
module s_ram_rst #(parameter data_width, parameter s_ram_addr_width) (clk, s_ram_reset_start, s_ram_reset_finish, s_ram_wren, s_ram_addr, s_ram_data, s_ram_access_granted, s_ram_access_request);
    input logic clk, s_ram_reset_start, s_ram_access_granted;
    output logic s_ram_reset_finish, s_ram_wren, s_ram_access_request;
    output logic [s_ram_addr_width-1:0] s_ram_addr;
    output logic [data_width-1:0] s_ram_data;
    
    // data will be the memory address itself
    assign s_ram_data = mem_num;
    assign s_ram_addr = mem_num;

    localparam state_bits = 8;
    logic [state_bits-1:0] state, next_state;
    assign s_ram_access_request = state[0];
    assign s_ram_wren = state[1];
    assign s_ram_reset_finish = state[2];
    assign mem_num_rst = state[3];
    assign mem_num_en = state[4];
 
    // state machine that fills memory with its address one by one
    vdff #(.N(state_bits)) state_dff (.clk(clk), .rst(1'b0), .d(next_state), .q(state));
    s_ram_rst_state_comb_logic #(.state_bits(state_bits),
                                 .s_ram_addr_width(s_ram_addr_width)) s_ram_rst_state_comb_logic1 (.state(state),
                                                                                                   .next_state(next_state), 
                                                                                                   .mem_num(mem_num), 
                                                                                                   .s_ram_reset_start(s_ram_reset_start), 
                                                                                                   .s_ram_access_granted(s_ram_access_granted));

    logic [s_ram_addr_width-1:0] mem_num, next_mem_num;
    logic mem_num_rst, mem_num_en;
    assign next_mem_num = mem_num_en ? (mem_num + {{s_ram_addr_width-1{1'b0}}, 1'b1}) : mem_num;

    // dff to store the memory address and data (sourced from same mem_num)
    vdff #(.N(s_ram_addr_width)) mem_num_dff (.clk(clk), .rst(mem_num_rst), .d(next_mem_num), .q(mem_num));
endmodule

// state machine combinational logic to determin the next state
module s_ram_rst_state_comb_logic #(parameter state_bits, parameter s_ram_addr_width) (state, next_state, mem_num, s_ram_reset_start, s_ram_access_granted);
    input [state_bits-1:0] state;
    input [s_ram_addr_width-1:0] mem_num;
    input s_ram_reset_start, s_ram_access_granted;
    output [state_bits-1:0] next_state;

    // state = {state_num, mem_num_en, mem_num_rst, s_ram_reset_finish, s_ram_wren, s_ram_access_request}
    localparam [state_bits-1:0] idle =             'b000_00000;
    localparam [state_bits-1:0] access_request =   'b001_00001;
    localparam [state_bits-1:0] reset_mem_num =    'b010_01001;
    localparam [state_bits-1:0] set_mem =          'b011_00011;
    localparam [state_bits-1:0] incr_addr =        'b100_10011;
    localparam [state_bits-1:0] reset_finished =   'b101_00100;

    always_comb begin
        case(state) 
            // waiting for start request to be asserted
            idle:           next_state = s_ram_reset_start ? access_request : idle;

            // request access to memory, if granted, reset memory number and start filling
            access_request: next_state = s_ram_access_granted ? reset_mem_num : access_request;
            reset_mem_num:  next_state = set_mem;
            
            // when last memory location is reached, reset is completed
            set_mem:        next_state = (mem_num == {s_ram_addr_width{1'b1}}) ? reset_finished : incr_addr;
            incr_addr:      next_state = set_mem;
            
            // start finish protocol waits until the start request is desserted to go back to idle
            reset_finished: next_state = s_ram_reset_start ? reset_finished : idle;
            default:        next_state = idle;
        endcase
    end
endmodule
`default_nettype wire