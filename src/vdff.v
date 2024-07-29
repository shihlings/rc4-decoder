`default_nettype none
//parameterized D-Flip-Flop
//N specifies number of bits for the flip flop
//synchronous reset only
module vdff #(parameter N) (d, rst, clk, q);
   input logic [N-1:0] d;
   input logic	       rst, clk;
   output logic [N-1:0]	q;

   always_ff @(posedge clk) begin
      if (rst)
	      q <= {N{1'b0}};
      else
	      q <= d;
   end
endmodule // vdff
`default_nettype wire
