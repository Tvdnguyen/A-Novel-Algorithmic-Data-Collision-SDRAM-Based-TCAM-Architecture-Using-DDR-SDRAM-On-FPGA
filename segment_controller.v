//////////////////////////////////////////////////////////
//	Category	  : Logic Design (Segment Engine)		//
//	Name File     : segment_controller.v                //
//	Author        : Dang Tieu Binh                      //
//	Email         : dangtieubinh0207@gmail.com          //
//	Standard      : IEEE 1800—2009(Verilog-2009)  		//
//	Start design  : 10.12.2021                          //
//	Last revision : 27.03.2022                          //
//////////////////////////////////////////////////////////

module segment_controller (
        // clock and reset
        input 		 clk
       ,input 		 reset
       
        // setting enable
       ,input 		 i_search_enable
       ,input		 i_setting_enable
       
        // control SDRAM i/o
       ,input 		 i_sdram_waitrequest
       ,input 		 i_sdram_readdatavalid
       ,output 	reg	 o_sdram_read
       ,output 	reg	 o_sdram_write
        
        // control DATAPATH i/o
       ,input 		 i_cntl_m0_modify_done
       ,output  	 o_cntl_m0_load
       ,output 	reg  o_cntl_m0_modify
       ,output	reg  o_cntl_m0_shift
       ,output  reg  o_cntl_m0_searchdatavalid
        
        // Setting/Searching complete notify
       ,output       o_search_complete
       ,output       o_setting_complete
	);

// ===================================================
//	 Parameters
// ===================================================	
    parameter  FRAGMENTS = 5;	// Number of fragments

// ===================================================
//	 Local Parameters
// ===================================================
    // State Encoding
    localparam IDLE        = 4'b0000; // 0
    localparam SHIFT       = 4'b0001; // 1
    localparam STABLE_RD_1 = 4'b0010; // 2
    localparam STABLE_RD_2 = 4'b0011; // 3
    localparam READ        = 4'b0100; // 4
    localparam MODIFY      = 4'b0101; // 5
    localparam STABLE_WR   = 4'b0110; // 6
    localparam WRITE       = 4'b0111; // 7
    localparam COUNT       = 4'b1000; // 8
	
// ===================================================
//	 Logic Declarations
// ===================================================
	// internal flag
	reg search_mode;
	reg setting_mode;

	// loop control 
	reg [3:0] loop_count; // Maximum 16 framents
	
	// -- Finite State Machine 
	reg [3:0] current_state; 
	
	always @(posedge clk or posedge reset)
	begin 
		if (reset) begin
			loop_count    <= FRAGMENTS;
			search_mode   <= 0;
			setting_mode  <= 0;
			current_state <= IDLE;
			
			// SDRAM control
			o_sdram_read     <= 0;
			o_sdram_write    <= 0;
			
			// Fragment control
			o_cntl_m0_shift  <= 0;
			
			// DataPath control
			o_cntl_m0_modify <= 0;
			
			// Search Data Valid 
			o_cntl_m0_searchdatavalid <= 0;
		end
		
		// out of reset 
		else begin 
			case (current_state) 
				// IDLE State 
				IDLE : begin
					// SDRAM control
					o_sdram_read     <= 0;
					o_sdram_write    <= 0;
					
					// Fragment control
					o_cntl_m0_shift  <= 0;
					
					// DataPath control
					o_cntl_m0_modify <= 0;
					
					// Search Data Valid 
					o_cntl_m0_searchdatavalid <= 0;
					
					// Internal flags 
					search_mode <= 0;
					setting_mode <= 0;
					
					// loop count
					loop_count <= FRAGMENTS;
					
					// Setting enable 
					if (i_setting_enable) begin
						setting_mode  <= 1'b1;  // Assert setting mode flag
						current_state <= SHIFT;	// Go to SHIFT
					end 
					
					// Search enable 
					else if (i_search_enable) begin 
						search_mode    <= 1'b1;  // Assert search mode flag
						current_state  <= SHIFT; // Go to SHIFT
					end 
					
					// Catch-all
					else begin 
						current_state <= IDLE;	// Wait here
					end 
				end 
				
				// SHIFT State : This state is for latching fragment key before readding
				SHIFT : begin 
					o_cntl_m0_shift <= 1'b1;
					current_state <= STABLE_RD_1; // Go to STABLE_RD
				end 
				
				// STABLE_RD_1 State : Extra clock cycle for DataPath latch data 
				STABLE_RD_1 : begin
					o_cntl_m0_shift <= 1'b0;
					current_state <= STABLE_RD_2;
				end
				
				// STABLE_RD_2 State : Extra clock cycle for DataPath latch data 
				STABLE_RD_2 : begin
					current_state <= READ;
				end
				
				// READ State 
				READ : begin
					o_sdram_read    <= 1'b1; // sdram read
					
					// waitrequest goes 1 means the SDRAM Controller have received signal
					if (i_sdram_waitrequest & !i_sdram_readdatavalid) begin 
						o_sdram_read    <= 1'b0; // Deassert read to prevent next reading
						current_state <= READ; // Wait here
					end
					
					// Readdatavalid & Setting Mode
					else if (i_sdram_waitrequest & i_sdram_readdatavalid & setting_mode) begin
						o_sdram_read    <= 1'b0; // Deassert read to prevent next reading
						current_state <= MODIFY; // Go to MODIFY
					end
					
					// Readdatavalid & Search Mode
					else if (i_sdram_waitrequest & i_sdram_readdatavalid & search_mode) begin
						o_sdram_read    <= 1'b0; // Deassert read to prevent next reading
						o_cntl_m0_searchdatavalid <= 1'b1; // Assert searchdatavalid
						current_state <= COUNT; // Go to COUNT
					end 
					
					// Catch-all
					else begin 
						current_state <= READ; // Wait here
					end 
				end 
				
				// MODIFY State 
				MODIFY : begin
					o_cntl_m0_modify <= 1'b1; // Assert modify signal				
					
					if (i_cntl_m0_modify_done == 1) begin 
						o_cntl_m0_modify <= 1'b0;
						current_state  <= STABLE_WR; // Go to STABLE_WR
					end 
					else begin
						current_state <= MODIFY; // Wait here
					end 
				end 
				
				// STABLE_WR State : Extra clock for Datapath latch writedata
				STABLE_WR : begin
					o_cntl_m0_modify <= 1'b0;
					current_state <= WRITE;
				end 
				
				// WRITE State
				WRITE : begin
					o_sdram_write    <= 1'b1;
					
					// waitrequest goes 1 means the SDRAM Controller have received signal
					if 	  (i_sdram_waitrequest) 	current_state <= COUNT;	// Go to COUNT
					else 						current_state <= WRITE;
				end 
				
				// COUNT State
				COUNT : begin
					// Deassert all cntl signals
					o_sdram_read  <= 1'b0;
					o_sdram_write <= 1'b0;
					o_cntl_m0_searchdatavalid <= 1'b0;
					
					if (loop_count > 1) begin 
						loop_count <= loop_count - 1;
						current_state <= SHIFT; // Continue to POST_READ
					end 
					else begin 
						current_state <= IDLE; // Everything done
					end 
				end
				
				// Catch-all
				default : begin
					current_state <= current_state;
				end	 
			endcase 
		end 
	end

	// Output Assignment
	assign o_cntl_m0_load 	  = (current_state==IDLE & reset==0) ? 1'b1 : 1'b0;
	assign o_search_complete  = (search_mode==0 	 & reset==0) ? 1'b1 : 1'b0;
	assign o_setting_complete = (setting_mode==0 	 & reset==0) ? 1'b1 : 1'b0;
	
endmodule 