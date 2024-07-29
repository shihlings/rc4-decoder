`default_nettype none
// state machine to check if data inside d_ram contains only lowercase letters and spaces
module d_ram_check_fsm #(parameter data_width, parameter addr_width) (clk, reset, d_ram_access_request, d_ram_access_granted, solution_correct, d_ram_addr, d_ram_q, d_ram_check_start, d_ram_check_finish);
    input logic clk, reset, d_ram_access_granted, d_ram_check_start;
    input logic [data_width-1:0] d_ram_q;
    output logic solution_correct, d_ram_check_finish, d_ram_access_request;
    output logic [addr_width-1:0] d_ram_addr;
    
    // declare state machine state bits
    localparam state_bits = 9;
    logic [state_bits-1:0] state, next_state;

    // assign state bits
    logic space_detected, lower_case_detected, last_addr_detected, increment_d_ram_addr, reset_d_ram_addr, found_solution, next_solution_correct;
    assign d_ram_check_finish = state[0];
    assign found_solution = state[1];
    assign d_ram_access_request = state[2];
    assign increment_d_ram_addr = state[3];
    assign reset_d_ram_addr = state[4];

    // dff to store solution correctness
    assign next_solution_correct = d_ram_check_finish ? found_solution : solution_correct;
    vdff #(.N(1)) solution_correct_dff (.d(next_solution_correct),
                                        .q(solution_correct),
                                        .rst(reset),
                                        .clk(clk));

    // dff to store address to process
    logic [addr_width-1:0] next_d_ram_addr;    
    vdff #(.N(addr_width)) d_ram_addr_dff (.d(next_d_ram_addr),
                                  .q(d_ram_addr),
                                  .rst(reset_d_ram_addr),
                                  .clk(clk));
    
    // logic to calculate outputs and valid data
    d_ram_check_arithmetic_logic #(.data_width(data_width),
                                   .addr_width(addr_width)) d_ram_check_arithmetic_logic_1 (.d_ram_q(d_ram_q), 
                                                                                            .space_detected(space_detected), 
                                                                                            .lower_case_detected(lower_case_detected), 
                                                                                            .last_addr_detected(last_addr_detected), 
                                                                                            .increment_d_ram_addr(increment_d_ram_addr), 
                                                                                            .next_d_ram_addr(next_d_ram_addr), 
                                                                                            .d_ram_addr(d_ram_addr));

    // dff to store current state
    vdff #(.N(state_bits)) d_ram_check_state_dff (.d(next_state),
                                                  .q(state),
                                                  .rst(reset),
                                                  .clk(clk));

    // combinational logic to determine next state
    d_ram_check_fsm_comb_logic #(.state_bits(state_bits)) d_ram_check_state_comb_logic_1 (.state(state),
                                                                                          .next_state(next_state), 
                                                                                          .d_ram_check_start(d_ram_check_start), 
                                                                                          .d_ram_access_granted(d_ram_access_granted), 
                                                                                          .space_detected(space_detected), 
                                                                                          .lower_case_detected(lower_case_detected), 
                                                                                          .last_addr_detected(last_addr_detected));
endmodule

// arithmetic and logic operations for d_ram_check_fsm
module d_ram_check_arithmetic_logic #(parameter data_width, parameter addr_width) (d_ram_q, space_detected, lower_case_detected, last_addr_detected, increment_d_ram_addr, next_d_ram_addr, d_ram_addr);
    input logic [data_width-1:0] d_ram_q;
    input logic [addr_width-1:0] d_ram_addr;
    input logic increment_d_ram_addr;
    output logic [addr_width-1:0] next_d_ram_addr;
    output logic space_detected, lower_case_detected, last_addr_detected;

    always_comb begin
        // increment d_ram_addr if increment_d_ram_addr is asserted
        if (increment_d_ram_addr)
            next_d_ram_addr = d_ram_addr + {{addr_width-1{1'b0}}, 1'b1};
        else
            next_d_ram_addr = d_ram_addr;
        
        // check if space, lower case letter, or last address is detected
        space_detected = 1'b0;
        lower_case_detected = 1'b0;
        last_addr_detected = 1'b0;
        
        // space has ASCII value of 32
        if (d_ram_q == 8'd32)
            space_detected = 1'b1;
        
        // lower case letters have ASCII values between 97 and 122
        if ((d_ram_q >= 8'd97) & (d_ram_q <= 8'd122))
            lower_case_detected = 1'b1;

        // last address is 2^addr_width - 1
        if (d_ram_addr == {addr_width{1'b1}})
            last_addr_detected = 1'b1;
    end
endmodule

// combinational logic for d_ram_check_fsm
module d_ram_check_fsm_comb_logic #(parameter state_bits) (state, next_state, d_ram_check_start, d_ram_access_granted, space_detected, lower_case_detected, last_addr_detected);
    input logic d_ram_check_start, d_ram_access_granted, space_detected, lower_case_detected, last_addr_detected;
    input logic [state_bits-1:0] state;
    output logic [state_bits-1:0] next_state;

    //state = {state_num, reset_d_ram_addr, increment_d_ram_addr, d_ram_access_request, solution_correct, d_ram_check_finish};
    localparam [state_bits-1:0] idle =               'b0000_00000; 
    localparam [state_bits-1:0] reset =              'b0001_10100; 
    localparam [state_bits-1:0] retrieve_data =      'b0010_00100;     
    localparam [state_bits-1:0] check_space =        'b0011_00100;   
    localparam [state_bits-1:0] check_lower_case =   'b0100_00100; 
    localparam [state_bits-1:0] check_last_addr =    'b0101_00100;       
    localparam [state_bits-1:0] fail =               'b0110_00001; 
    localparam [state_bits-1:0] pass =               'b0111_00011; 
    localparam [state_bits-1:0] increment_addr =     'b1000_01100;
    localparam [state_bits-1:0] request_mem_access = 'b1001_00100;
     
    always_comb begin
        case (state)
            idle: next_state = d_ram_check_start ? request_mem_access : idle;
            request_mem_access: next_state = d_ram_access_granted ? reset : request_mem_access;
            reset: next_state = retrieve_data;
            retrieve_data: next_state = check_space;
            check_space: next_state = space_detected ? check_last_addr : check_lower_case;
            check_lower_case: next_state = lower_case_detected ? check_last_addr : fail;      
            check_last_addr: next_state = last_addr_detected ? pass : increment_addr;
            increment_addr: next_state = retrieve_data;
            fail: next_state = d_ram_check_start ? fail : idle;
            pass: next_state = d_ram_check_start ? pass : idle;
            default: next_state = idle;
        endcase
    end
endmodule
`default_nettype wire