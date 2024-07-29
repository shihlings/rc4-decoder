`default_nettype none
// state machine to start cores
module start_cores_fsm #(parameter cores) (core_start, start_all_cores, end_all_cores, rst, clk, increment_secret_key, finished_start_cores, update_core_secret_key);
    input logic start_all_cores, rst, clk, end_all_cores;
    output logic [cores-1:0] core_start, update_core_secret_key;
    output logic increment_secret_key, finished_start_cores;

    // dff to store core counter
    localparam counter_bits = $clog2(cores) + 1;
    logic [counter_bits-1:0] current_core, next_core;
    logic reset_core_counter;    
    vdff #(.N(counter_bits)) core_counter_dff (.d(next_core), 
                                               .rst(reset_core_counter), 
                                               .clk(clk), 
                                               .q(current_core));
    
    // dff to store core start values
    logic [cores-1:0] next_core_start;
    vdff #(.N(cores)) core_start_dff (.d(next_core_start), 
                                      .rst(~core_on), 
                                      .clk(clk), 
                                      .q(core_start));

    // dff to store current state                                  
    vdff #(.N(state_bits)) stateDFF (.d(next_state), 
                                     .rst(1'b0), 
                                     .clk(clk), 
                                     .q(state));

    // state bits assignments
    localparam state_bits = 7;
    logic [state_bits-1:0] state, next_state;
    logic increment_secret_key_counter, core_on;
    assign reset_core_counter = state[0];
    assign increment_secret_key_counter = state[1];
    assign core_on = state[2];
    assign finished_start_cores = state[3];
    assign increment_secret_key = increment_secret_key_counter;
    assign next_core = increment_secret_key_counter ? (current_core + 1'b1) : current_core;

    genvar i;
    generate
        for (i=0; i<cores; i++) begin: SET_CORE_START_VAL
            // start cores according to current_core counter and core_on state
            assign next_core_start[i] = (core_on && current_core == i) ? 1'b1 : core_start[i];

            // update core secret key according to current_core counter and increment_secret_key_counter state
            assign update_core_secret_key[i] = (increment_secret_key_counter && current_core == i) ? 1'b1 : 1'b0;
        end
    endgenerate

    // combinational logic to determine next state
    start_cores_fsm_comb_logic #(.state_bits(state_bits),
                                 .counter_bits(counter_bits),
                                 .cores(cores)) start_cores_fsm_comb_logic_1 (.state(state),
                                                                              .next_state(next_state), 
                                                                              .start_all_cores(start_all_cores),
                                                                              .end_all_cores(end_all_cores),
                                                                              .rst(rst),
                                                                              .current_core(current_core));
endmodule

// combinational logic to determine next state
module start_cores_fsm_comb_logic #(parameter state_bits, parameter cores, parameter counter_bits) (state, next_state, start_all_cores, end_all_cores, rst, current_core);
    input logic [state_bits-1:0] state;
    input logic [counter_bits-1:0] current_core;
    input logic start_all_cores, end_all_cores, rst;
    output logic [state_bits-1:0] next_state;
    
    // state = {state_bits, finished_start_cores, core_on, increment_secret_key_counter, reset_core_counter}
    localparam [state_bits-1:0] idle =                          'b000_0001;
    localparam [state_bits-1:0] start_core =                    'b001_0100;
    localparam [state_bits-1:0] increment_secret_key_and_core = 'b010_0110;
    localparam [state_bits-1:0] finished_start_cores =          'b011_1100;
    localparam [state_bits-1:0] reset_core_counter =            'b100_0101;
    localparam [state_bits-1:0] end_core =                      'b101_0000;
    
    always_comb begin
        if (rst) begin
            next_state = idle;
        end
        else begin
            case (state)
                idle: next_state = start_all_cores ? start_core : idle;

                // start core
                start_core: next_state = increment_secret_key_and_core;
                
                // increment core counter and secret_key
                // if all cores are started, go to finished_start_cores
                // else keep starting cores
                increment_secret_key_and_core: begin
                    if (current_core >= (cores-1)) begin
                        next_state = finished_start_cores;
                    end 
                    else begin 
                        next_state = start_core;
                    end
                end

                // wait until signal received to end all cores to reset core counter and end cores
                finished_start_cores: next_state = end_all_cores ? reset_core_counter : finished_start_cores;
                reset_core_counter: next_state = end_core;
                end_core: next_state = idle;
                
                default: next_state = idle;
            endcase
        end
    end
endmodule

`default_nettype wire