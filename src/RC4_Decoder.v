// RC4 Decoder module, parameter cores is the number of cores to instantiate
// currently default is set to 1 to prevent issues, all design should work with generates to allow multi-core instantiation
`default_nettype none
module RC4_Decoder #(parameter cores = 64, 
                     parameter addr_width = 5, 
                     parameter data_width = 8, 
                     parameter secret_key_length = 24) (SW, KEY, LEDR, clk, reset, nOut);
    input logic [9:0] SW;
    input logic [3:0] KEY;
    input logic clk, reset;
    output logic [3:0] nOut [5:0];
    output logic [9:0] LEDR;

    // LED output
    // LED[0] = found solution
    // LED[1] = no solution found in entire keyspace
    assign LEDR = {8'b0, no_solution, found_solution};

    // signal for the state machine to know if the solution is found
    logic found_solution, no_solution, all_cores_finish, copy_key_solution_finish, copy_e_rom_to_ram_finish, finish_start_all, end_all_cores, start_all_cores, copy_key_solution_start, copy_e_rom_to_ram_start;
    assign found_solution = |solution_correct;
    assign all_cores_finish = &core_finish;

    // instantiate sol_ram to store final solution
    logic [addr_width-1:0] sol_ram_addr;
    logic [data_width-1:0] sol_ram_data;
    logic sol_ram_wren;
    sol_memory sol_ram (.address(sol_ram_addr),
                        .clock(clk),
                        .data(sol_ram_data),
                        .wren(sol_ram_wren),
                        .q());        

    // Instantiate the Encrypted ROM (e_rom)
    // stores the secret key (master) - gets copied to e_ram of each core later
    logic [addr_width-1:0] e_rom_addr;
    logic [data_width-1:0] e_rom_q;
    encrypted_rom encrypted_rom_1 (.address(e_rom_addr),
                                   .clock(clk), 
                                   .q(e_rom_q));

    // Instantiate state machine to control and coordinate cores
    logic [data_width-1:0] solution_d_ram_q;
    logic [addr_width-1:0] solution_d_ram_addr;
    logic solution_d_ram_access_request, solution_d_ram_access_granted;
    multicore_state_machine #(.secret_key_length(secret_key_length)) multicore_state_machine_1 (.clk(clk), 
                                                                                                .reset(reset), 
                                                                                                .found_solution(found_solution), 
                                                                                                .copy_key_solution_finish(copy_key_solution_finish), 
                                                                                                .copy_e_rom_to_ram_finish(copy_e_rom_to_ram_finish), 
                                                                                                .all_cores_finish(all_cores_finish), 
                                                                                                .finish_start_all(finish_start_all),
                                                                                                .secret_key(secret_key), 
                                                                                                .reset_secret_key(reset_secret_key), 
                                                                                                .no_solution(no_solution), 
                                                                                                .end_all_cores(end_all_cores), 
                                                                                                .start_all_cores(start_all_cores), 
                                                                                                .copy_key_solution_start(copy_key_solution_start), 
                                                                                                .copy_e_rom_to_ram_start(copy_e_rom_to_ram_start));

    // fsm to start each core individually and assign secret keys
    // also ends the fsm afterwards
    start_cores_fsm #(.cores(cores)) start_cores_fsm_1 (.core_start(core_start), 
                                                        .start_all_cores(start_all_cores), 
                                                        .end_all_cores(end_all_cores), 
                                                        .rst(reset), 
                                                        .clk(clk), 
                                                        .increment_secret_key(increment_secret_key),
                                                        .finished_start_cores(finish_start_all),
                                                        .update_core_secret_key(update_core_secret_key));

    // copies the e_rom data to e_ram data of each core at the start of the entire decryption process
    copy_memory_fsm #(.data_width(data_width),
                      .addr_width(addr_width)) copy_e_rom_to_ram_fsm (.source_q(e_rom_q),
                                                                      .source_addr(e_rom_addr),
                                                                      .destination_data(e_ram_data),
                                                                      .destination_addr(e_ram_addr),
                                                                      .destination_wren(e_ram_wren),
                                                                      .clk(clk), 
                                                                      .reset(reset),
                                                                      .start(copy_e_rom_to_ram_start), 
                                                                      .finish(copy_e_rom_to_ram_finish),
                                                                      .access_source_request(),
                                                                      .access_source_granted(1'b1),
                                                                      .access_destination_request(e_ram_access_request),
                                                                      .access_destination_granted(e_ram_access_granted));

    // copies the solution from the d_ram of the core that found the solution to the sol_ram
    copy_memory_fsm #(.data_width(data_width),
                      .addr_width(addr_width)) copy_d_ram_to_sol_ram_fsm (.source_q(solution_d_ram_q),
                                                                          .source_addr(solution_d_ram_addr),
                                                                          .destination_data(sol_ram_data),
                                                                          .destination_addr(sol_ram_addr),
                                                                          .destination_wren(sol_ram_wren),
                                                                          .clk(clk), 
                                                                          .reset(reset),
                                                                          .start(copy_key_solution_start), 
                                                                          .finish(copy_key_solution_finish),
                                                                          .access_source_request(solution_d_ram_access_request),
                                                                          .access_source_granted(solution_d_ram_access_granted),
                                                                          .access_destination_request(),
                                                                          .access_destination_granted(1'b1));

    // multiplexer to select which core's d_ram to control
    generate
        for (i=0 ; i<cores ; i++) begin: CORE_D_RAM_Q_SELECT
            assign d_ram_addr[i] = solution_correct[i] ? solution_d_ram_addr : {addr_width{1'bz}};
            assign d_ram_access_request[i] = solution_correct[i] ? solution_d_ram_access_request : 1'b0;
        end
    endgenerate

    // multiplexer to select which core's d_ram to read from
    always_comb begin
        solution_d_ram_access_granted = 1'bz;
        solution_d_ram_q = {data_width{1'bz}};

        for (int i=0 ; i<cores ; i++) begin: SOLUTION_D_RAM_SELECT
            if (solution_correct[i]) begin
                solution_d_ram_q = d_ram_q[i];
                solution_d_ram_access_granted = d_ram_access_granted[i];
            end
        end
    end

    // Output current secret on the HEX display
    genvar i;
    generate
        for (i=0 ; i<6 ; i++) begin: HEX_DISPLAY
            always_comb begin
                // display latest key on HEX display
                nOut[i] = secret_key[(i+1)*4-1:i*4];

                // if solution is found in one of the cores, display the secret key of that core on HEX display
                for (int core_i=0 ; core_i<cores ; core_i++) begin: SOLUTION_SECRET_KEY_TO_HEX
                    if (solution_correct[core_i]) begin
                        nOut[i] = core_secret_key[core_i][(i+1)*4-1:i*4];
                    end
                end
            end
        end
    endgenerate
    
    // instantiate the secret key dff
    logic increment_secret_key, reset_secret_key;
    logic [secret_key_length:0] secret_key, next_secret_key;
    vdff #(.N(secret_key_length+1)) secret_key_dff (.clk(clk), .rst(reset_secret_key), .d(next_secret_key), .q(secret_key));
    always_comb begin
        if (increment_secret_key && (secret_key <= {1'b0, {secret_key_length{1'b1}}})) begin
            next_secret_key = secret_key + {{secret_key_length{1'b0}}, 1'b1};
        end
        else begin
            next_secret_key = secret_key;
        end
    end

    // instantiate dffs to store the secret key for each core
    logic [secret_key_length-1:0] core_secret_key [cores-1:0];
    logic [secret_key_length-1:0] next_core_secret_key [cores-1:0];
    logic [cores-1:0] update_core_secret_key;
    generate
        for (i=0 ; i<cores ; i++) begin: CORE_SECRET_KEY_DFF
            assign next_core_secret_key[i] = update_core_secret_key[i] ? secret_key[secret_key_length-1:0] : core_secret_key[i];
            vdff #(.N(secret_key_length)) core_secret_key_dff (.clk(clk), .rst(reset_secret_key), .d(next_core_secret_key[i]), .q(core_secret_key[i]));
        end
    endgenerate

    // Generate the RC4 Decoder Cores
    logic [cores-1:0] core_start, core_finish, solution_correct, d_ram_access_request, d_ram_access_granted, e_ram_access_granted;
    logic e_ram_access_request, e_ram_wren;
    logic [addr_width-1:0] e_ram_addr;
    logic [data_width-1:0] e_ram_data;
    logic [addr_width-1:0] d_ram_addr [cores-1:0];
    logic [data_width-1:0] d_ram_q [cores-1:0];
    generate
        for (i=0 ; i<cores ; i++) begin : MULTI_CORE_INST
            rc4_decoder_core #(.secret_key_length(secret_key_length),
                               .addr_width(addr_width),
                               .data_width(data_width)) core_inst (.clk(clk),
                                                                   .reset(reset),
                                                                   .secret_key(core_secret_key[i]), 
                                                                   .core_start(core_start[i]), 
                                                                   .core_finish(core_finish[i]), 
                                                                   .solution_correct(solution_correct[i]), 
                                                                   .d_ram_access_request_ext(d_ram_access_request[i]),
                                                                   .d_ram_access_granted_ext(d_ram_access_granted[i]),
                                                                   .d_ram_addr_ext(d_ram_addr[i]), 
                                                                   .d_ram_q(d_ram_q[i]),
                                                                   .e_ram_access_granted_ext(e_ram_access_granted[i]),
                                                                   .e_ram_access_request_ext(e_ram_access_request), 
                                                                   .e_ram_addr_ext(e_ram_addr), 
                                                                   .e_ram_data_ext(e_ram_data),
                                                                   .e_ram_wren_ext(e_ram_wren));
        end
    endgenerate
endmodule
`default_nettype wire   