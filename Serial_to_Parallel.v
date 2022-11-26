module Serial_to_Parallel (
		clk,
		rst, 
		
		i_Serial,
		o_Parallel
	);
// =================================================================
// == Parameters
// =================================================================
	parameter N = 10;
	
// =================================================================
// == Port Declarations
// ================================================================= 
	input clk;
	input rst; 
	
	// inputs 
	input 			i_Serial;
	
	// outputs
	output 	[N-1:0] o_Parallel;
	
// =================================================================
// == Signal Declarations
// =================================================================
	reg [N-1:0] Data_Out;
	
// =================================================================
// == Architecture
// ================================================================= 	
	always @(posedge clk or posedge rst)	// -- Async Reset
	begin
		if 	  (rst == 1)  	Data_Out <= 0;
		else 				Data_Out <= {i_Serial, Data_Out[N-1:1]};
	end 
	
	// Assignments
	assign o_Parallel = Data_Out;
	
endmodule