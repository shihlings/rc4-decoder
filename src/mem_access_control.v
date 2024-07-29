`default_nettype none
// Controlls who currently has read/write control of the memory and passes it to the memory module
// num_mem_access - number of access ports to the memory module
// start finish protocol used with mem_access_request and mem_access_granted
module mem_access_control #(parameter num_mem_access, parameter data_width, parameter addr_width) (clk, reset_controller, mem_access_request, mem_access_granted, in_mem_addr, in_mem_data, in_mem_wren, out_mem_addr, out_mem_data, out_mem_wren);
    input logic clk, reset_controller;
    input logic [num_mem_access-1:0] mem_access_request, in_mem_wren;
    input logic [addr_width-1:0] in_mem_addr [num_mem_access-1:0];
    input logic [data_width-1:0] in_mem_data [num_mem_access-1:0];
    output logic [addr_width-1:0] out_mem_addr;
    output logic [data_width-1:0] out_mem_data;
    output logic [num_mem_access-1:0] mem_access_granted;
    output logic out_mem_wren; 

    // master state machine that rotates between access state machines
    logic [num_mem_access-1:0] access_num_state, access_status;
    rotate_access #(.num_mem_access(num_mem_access)) rotate_access_controller_1 (.clk(clk), 
                                                                                 .reset_controller(reset_controller), 
                                                                                 .access_num_state(access_num_state), 
                                                                                 .access_status(access_status));
    
    // instantiate as many access state machines as there are access ports
    genvar i;
    generate
        for (i=0 ; i<num_mem_access ; i++) begin : ACCESS_STATE_INST
            access_state_control access_state_inst (.clk(clk),
                                                    .reset_controller(reset_controller),
                                                    .access_num_state(access_num_state[i]),
                                                    .mem_access_granted(mem_access_granted[i]),
                                                    .mem_access_request(mem_access_request[i]),
                                                    .access_status(access_status[i]));
        end
    endgenerate
    
    // output selector module to select which memory access port to pass to the memory module
    output_selector #(.num_mem_access(num_mem_access),
                      .addr_width(addr_width),
                      .data_width(data_width)) output_selector_1 (.mem_access_granted(mem_access_granted),
                                                                  .in_mem_addr(in_mem_addr),
                                                                  .in_mem_data(in_mem_data),
                                                                  .in_mem_wren(in_mem_wren),
                                                                  .out_mem_addr(out_mem_addr),
                                                                  .out_mem_data(out_mem_data),
                                                                  .out_mem_wren(out_mem_wren));
endmodule

// rotates between access_control state machines to give each access port a chance to access the memory
module rotate_access #(parameter num_mem_access) (clk, reset_controller, access_num_state, access_status);
    input logic clk, reset_controller;
    input logic [num_mem_access-1:0] access_status;
    output logic [num_mem_access-1:0] access_num_state;

    always_ff @(posedge clk) begin
        if (reset_controller) begin
            access_num_state <= {{num_mem_access-1{1'b0}}, 1'b1};
        end
        else begin
            if (access_status == {{num_mem_access{1'b0}}})
                access_num_state <= {access_num_state[num_mem_access-2:0], access_num_state[num_mem_access-1]};
        end
    end
endmodule

// Checks if access request is asserted and grants access if it is
module access_state_control (clk, reset_controller, access_num_state, mem_access_granted, mem_access_request, access_status);
    input logic clk, reset_controller, access_num_state, mem_access_request;
    output logic mem_access_granted, access_status;
    
    localparam state_bits = 2;
    logic [state_bits-1:0] state;
    assign mem_access_granted = state[0];
    assign access_status = state[1];

    localparam [state_bits-1:0] idle                         = 'b00;
    localparam [state_bits-1:0] check_mem_access_request     = 'b10;
    localparam [state_bits-1:0] mem_access_granted_state     = 'b11;
    
    always_ff @(posedge clk) begin
       case (state)
            idle: state <= access_num_state ? check_mem_access_request : idle;
            check_mem_access_request: state <= mem_access_request ? mem_access_granted_state : idle;
            mem_access_granted_state: state <= mem_access_request ? mem_access_granted_state : idle;
            default: state <= idle;
        endcase
    end
endmodule

// Selects which memory access port to pass to the memory module
module output_selector #(parameter num_mem_access, parameter data_width, parameter addr_width) (mem_access_granted, in_mem_addr, in_mem_data, in_mem_wren, out_mem_addr, out_mem_data, out_mem_wren);
    input logic [num_mem_access-1:0] mem_access_granted, in_mem_wren;
    input logic [addr_width-1:0] in_mem_addr [num_mem_access-1:0];
    input logic [data_width-1:0] in_mem_data [num_mem_access-1:0];
    output logic [addr_width-1:0] out_mem_addr;
    output logic [data_width-1:0] out_mem_data;
    output logic out_mem_wren;
    
    // muxes and buffers to select which input goes to the output according to access granted signal
    always_comb begin    
        out_mem_addr = {addr_width{1'bz}};
        out_mem_data = {data_width{1'bz}};
        out_mem_wren = 1'b0;

        for (int i=0 ; i<num_mem_access ; i++) begin : ACCESS_MUX_INST
            if (mem_access_granted[i] == 1'b1) begin
                out_mem_addr = in_mem_addr[i];
                out_mem_data = in_mem_data[i];
                out_mem_wren = in_mem_wren[i];
            end
        end
    end
endmodule
`default_nettype wire