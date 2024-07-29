`default_nettype none 
// state machine to manipulate secret key dffs and coordinate cores
module multicore_state_machine #(parameter secret_key_length) (clk, reset, found_solution, copy_key_solution_finish, copy_e_rom_to_ram_finish, all_cores_finish, finish_start_all, secret_key, reset_secret_key, no_solution, end_all_cores, start_all_cores, copy_key_solution_start, copy_e_rom_to_ram_start);
    input logic clk, reset, found_solution, copy_key_solution_finish, copy_e_rom_to_ram_finish, all_cores_finish, finish_start_all;
    input logic [secret_key_length:0] secret_key;
    output logic reset_secret_key, no_solution, end_all_cores, start_all_cores, copy_key_solution_start, copy_e_rom_to_ram_start;

    // assign outputs based on state
    assign end_all_cores = state[0];
    assign reset_secret_key = state[1];
    assign start_all_cores = state[2];
    assign copy_key_solution_start = state[3];
    assign copy_e_rom_to_ram_start = state[4];
    assign no_solution = state[5];

    // dff to keep track of current state
    localparam state_bits = 9;
    logic [state_bits-1:0] state, next_state;
    vdff #(.N(state_bits)) stateDFF (.d(next_state),
                                     .rst(1'b0), 
                                     .clk(clk), 
                                     .q(state));

    //combinational logic to determine next state             
    multicore_state_machine_comb_logic #(.state_bits(state_bits),
                                         .secret_key_length(secret_key_length)) multicore_state_machine_comb_logic_1 (.state(state), 
                                                                                                                      .next_state(next_state), 
                                                                                                                      .finish_start_all(finish_start_all), 
                                                                                                                      .all_cores_finish(all_cores_finish), 
                                                                                                                      .found_solution(found_solution),
                                                                                                                      .copy_key_solution_finish(copy_key_solution_finish), 
                                                                                                                      .copy_e_rom_to_ram_finish(copy_e_rom_to_ram_finish),
                                                                                                                      .reset(reset),
                                                                                                                      .secret_key(secret_key));
endmodule

module multicore_state_machine_comb_logic #(parameter state_bits, parameter secret_key_length) (state, next_state, finish_start_all, all_cores_finish, found_solution, copy_key_solution_finish, copy_e_rom_to_ram_finish, reset, secret_key);
    input logic [state_bits-1:0] state;
    input logic [secret_key_length:0] secret_key;
    input logic finish_start_all, all_cores_finish, found_solution, copy_key_solution_finish, copy_e_rom_to_ram_finish,reset;
    output logic [state_bits-1:0] next_state;
    
    // state = {state_bits, no_solution, copy_e_rom_to_ram_start, copy_solution_start, start_all_cores, reset_secret_key, end_all_cores}
    localparam [state_bits-1:0] reset_secret_key =  'b000_000_010;
    localparam [state_bits-1:0] copy_e_rom_to_ram = 'b001_010_000;
    localparam [state_bits-1:0] start_all =         'b010_000_100;
    localparam [state_bits-1:0] wait_all_cores =    'b011_000_000;
    localparam [state_bits-1:0] check_solution =    'b100_000_001;
    localparam [state_bits-1:0] copy_solution =     'b101_001_001;
    localparam [state_bits-1:0] soltuion_found =    'b110_000_001;
    localparam [state_bits-1:0] not_found =         'b111_100_001;
    
    always_comb begin 
        if (reset) begin
            next_state = reset_secret_key;
        end
        else begin
            case (state)
                // reset secret key back to 00000000
                reset_secret_key: next_state = copy_e_rom_to_ram;

                // copy e_rom to e_ram of each core
                copy_e_rom_to_ram: next_state = copy_e_rom_to_ram_finish ? start_all : copy_e_rom_to_ram;

                // start each core individually with a different secret key
                start_all: next_state = finish_start_all ? wait_all_cores : start_all;

                // wait for all cores to finish
                wait_all_cores: next_state = all_cores_finish ? check_solution : wait_all_cores;

                // check if any core found the solution
                // if found - copy solution
                // if end of keyspace reached - end state machine and indicate no solution found
                // otherwise - keep searching
                check_solution: begin
                    if (found_solution) begin
                        next_state = copy_solution;
                    end
                    else if (secret_key > {1'b0, {24{1'b1}}}) begin
                        next_state = not_found;
                    end
                    else begin
                        next_state = start_all;
                    end
                end

                // copy solution from d_ram of core that found the solution to sol_ram
                copy_solution: next_state = copy_key_solution_finish ? soltuion_found : copy_solution;

                // complete states
                soltuion_found: next_state = soltuion_found;
                not_found: next_state = not_found;

                default: next_state = reset_secret_key;
            endcase
        end
    end
endmodule
`default_nettype wire