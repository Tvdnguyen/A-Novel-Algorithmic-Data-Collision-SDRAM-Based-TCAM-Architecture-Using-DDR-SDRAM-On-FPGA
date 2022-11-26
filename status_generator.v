////////////////////////////////////////////////////////////
//	Category	  : Logic Design (Status DataPath)		  //
//	Name File     : status_generator.v 					  //
//	Author        : Dang Tieu Binh                        //
//	Email         : dangtieubinh0207@gmail.com            //
//	Standard      : IEEE 1800—2009(Verilog-2009)  		  //
//	Start design  : 06.12.2021                            //
//	Last revision : 25.05.2021                            //
////////////////////////////////////////////////////////////

module status_generator (
        // clock and reset
        input			            clk
       ,input 			            reset 
        
        // setting i/o
       ,input 						i_modify
       ,input       [    KWID-1:0 ] i_setting_key
       ,input  		[   IDWID-1:0 ]	i_setting_id
       ,input 		[ MASKWID-1:0 ]	i_setting_maskid
       ,input       [ PRIOWID-1:0 ] i_setting_priority
       
        // SDRAM i/o
       ,input		[  SEGWID-1:0 ]	i_sdram_readdata
       ,output 	reg	[  SEGWID-1:0 ]	o_sdram_writedata
       
        // Control i/o
       ,output 	 					o_modify_complete
	);

// ===================================================
//	 Parameters
// ===================================================	
    parameter   DATA_BITS = 10; // Key length
    parameter   FRAGMENTS = 5;	// Number of fragments
    parameter   FRAG_BITS = 3;	// Number of bits represent for number of fragments
    parameter   IDWID     = 2;  // ID width
    parameter   MASKWID   = 5;

// ===================================================
//	 Local Parameters
// ===================================================
    localparam  FRAG_WID  = (DATA_BITS/FRAGMENTS);
    localparam  ADDR_WID  = FRAG_BITS+FRAG_WID;
    localparam  PRIOWID   = IDWID;
    localparam  KWID      = DATA_BITS;
    localparam  SEGWID    = 2+IDWID+MASKWID+KWID+PRIOWID; // 2-bit status + ID + MASK + KEY + PRIORITY

// ===================================================
//	 State Encoding 
// ===================================================
    localparam IDLE     = 0;
    localparam MODIFY   = 1;
    localparam COMPLETE = 2;
	
// ===================================================
//	 Logic Declarations
// ===================================================
    // Cell Empty
    wire cell_empty;
    assign cell_empty = ~i_sdram_readdata[SEGWID-2];
    
    // Finite State Machine
    reg [		1:0] current_state;
    reg [SEGWID-1:0] writedata_mod;
    reg				 reg_modify_complete;
    
    always @(posedge clk or posedge reset) 
    begin 
        if (reset) begin
            writedata_mod <= 0;
            current_state <= IDLE;
            reg_modify_complete	<= 0;
        end
        
        // out of reset
        else begin 
            case (current_state)
                // IDLE State 
                IDLE : begin
                    reg_modify_complete <= 1'b0;
                    
                    if   (i_modify)	current_state <= MODIFY; // Go to i_modify
                    else            current_state <= IDLE; // Wait here
                end 
            
                // MODIFY State
                MODIFY : begin
                    reg_modify_complete <= 1'b0;
                    
                    // cell empty 
                    if (cell_empty) begin 
                        writedata_mod <= {2'b01, i_setting_id, i_setting_maskid, i_setting_key, i_setting_priority};
                        reg_modify_complete <= 1'b1;
                        current_state <= COMPLETE;	// Go to COMPLETE
                    end
                    
                    // cell not empty
                    else begin 
                        writedata_mod <= {2'b11, i_sdram_readdata[SEGWID-3:0]};
                        reg_modify_complete <= 1'b1;
                        current_state <= COMPLETE;	// Go to COMPLETE
                    end 
                end 
                
                // COMPLETE State 
                COMPLETE : begin 
                    reg_modify_complete <= 1'b1;
                    current_state <= IDLE; // Go to IDLE
                end 
            
                // Catch-all 
                default : begin 
                    writedata_mod <= writedata_mod;
                end 
            endcase 
        end 
    end
    
    // Ouptut assignment
    always @(posedge clk or posedge reset)
    begin 
        if (reset) begin 
            o_sdram_writedata <= 0;
        end 
        
        // i_modify complete
        else if (reg_modify_complete) begin 
            o_sdram_writedata <= writedata_mod;
        end
        
        // catch-all 
        else begin 
            o_sdram_writedata <= o_sdram_writedata;
        end 
    end 
    
    assign o_modify_complete = reg_modify_complete;
endmodule
