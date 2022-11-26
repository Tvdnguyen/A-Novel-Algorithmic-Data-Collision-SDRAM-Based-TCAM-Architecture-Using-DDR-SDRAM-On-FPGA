//////////////////////////////////////////////////////////
//  Category      : Logic Design (TCAM)                 //
//  Name File     : priority_engine.v                   //
//  Author        : Dang Tieu Binh                      //
//  Email         : dangtieubinh0207@gmail.com          //
//  Standard      : IEEE 1800—2009(Verilog-2009)        //
//  Start design  : 05.10.2022                          //
//  Last revision : 06.10.2022                          //
//          ** DO NOT DELETE THIS CONTRIBUTION **       //
//////////////////////////////////////////////////////////

module priority_engine (
        // clock and reset 
        input                   clk
       ,input                   reset
        
        // data i/o
       ,input  [   IDWID-1:0 ]  i_confirm_ruleid
       ,input  [ PRIOWID-1:0 ]  i_confirm_priority
       ,output [   IDWID-1:0 ]  o_final_id
       ,output                  o_mismatch
       
        // control i/o
       ,input                   i_confirm_valid
       ,input                   i_confirm_complete
       ,output                  o_priority_complete
    );
// ===================================================
//	 Parameters
// ===================================================	
    parameter	DATA_BITS = 10; // Key length
    parameter 	FRAGMENTS = 5;	// Number of fragments
    parameter 	FRAG_BITS = 3;	// Number of bits represent for number of fragments
    parameter	IDWID     = 2;  // ID width
    parameter   MASKWID   = 5;

// ===================================================
//	 Local Parameters
// ===================================================
    localparam  PRIOWID   = IDWID;
    localparam  KWID      = DATA_BITS;
    localparam  SEGWID    = 2+IDWID+MASKWID+KWID+PRIOWID; // 2-bit status + ID + MASK + KEY + PRIORITY

// ===================================================
//	 Input Register
// ===================================================

    // Confirm complete pulse 
    
    reg r_confirm_complete_sync1;
    
    always @(posedge clk or posedge reset)
    begin 
        if   (reset) r_confirm_complete_sync1 <= 0;
        else         r_confirm_complete_sync1 <= i_confirm_complete;
    end 

    wire p_confirm_complete;
    assign p_confirm_complete = (i_confirm_complete & ~r_confirm_complete_sync1);
    
    wire p_confirm_processing; 
    assign p_confirm_processing = (~i_confirm_complete & r_confirm_complete_sync1);
    
    // Data
    
    reg [  IDWID-1:0] r_confirm_ruleid;
    reg [PRIOWID-1:0] r_confirm_priority;
    
    always @(posedge clk or posedge reset)
    begin 
        if (reset) begin 
            r_confirm_ruleid   <= 'h0;
            r_confirm_priority <= 'h0;
        end 
        else if (i_confirm_complete) begin 
            r_confirm_ruleid   <= 'h0;
            r_confirm_priority <= 'h0;
        end
        else if (i_confirm_valid) begin 
            r_confirm_ruleid   <= i_confirm_ruleid;
            r_confirm_priority <= i_confirm_priority;
        end  
        else begin 
            r_confirm_ruleid   <= r_confirm_ruleid;  
            r_confirm_priority <= r_confirm_priority;
        end 
    end 
    

// ===================================================
//	 Logic Declarations
// ===================================================
    
    // Priority compare
    
    wire w_id_select; 
    assign w_id_select = (r_confirm_priority > r_stored_priority) ? 1'b1 : 1'b0;
    
    // -----------------------------------------------
    //	 Address Selection
    // -----------------------------------------------
    
    reg [  IDWID-1:0] r_stored_id; 
    reg [PRIOWID-1:0] r_stored_priority;
    
    always @(posedge clk or posedge reset)
    begin 
        if (reset) begin 
            r_stored_id       <= 'h0;
            r_stored_priority <= 'h0;
        end 
        else if (p_confirm_complete) begin 
            r_stored_id       <= 'h0;
            r_stored_priority <= 'h0;
        end
        else if (w_id_select) begin 
            r_stored_id       <= r_confirm_ruleid;
            r_stored_priority <= r_confirm_priority;
        end
        else begin 
            r_stored_id       <= r_stored_id;
            r_stored_priority <= r_stored_priority;      
        end 
    end 
    
    // -----------------------------------------------
    //	 Output Register
    // -----------------------------------------------
    
    // mismatch signals
    
    wire w_id_match;
    assign w_id_match = ( i_confirm_valid & ~i_confirm_complete );
   
    reg ro_mismatch;
    
    always @(posedge clk or posedge reset)
    begin 
        if      ( reset              ) ro_mismatch <= 1'b1; // initial value
        else if ( p_confirm_complete ) ro_mismatch <= 1'b1;
        else if ( w_id_match         ) ro_mismatch <= 1'b0;
        else                           ro_mismatch <= ro_mismatch;
    end
    
    assign o_mismatch = ro_mismatch;
    
    // priority complete
    
    reg ro_priority_complete;
    
    always @(posedge clk or posedge reset)
    begin 
        if      ( reset                )  ro_priority_complete <= 1'b0;
        else if ( p_confirm_complete   )  ro_priority_complete <= 1'b1;
        else if ( p_confirm_processing )  ro_priority_complete <= 1'b0;
        else                              ro_priority_complete <= 1'b0;
    end
    
    assign o_priority_complete = ro_priority_complete;
    
    // ID 
    
    reg [IDWID-1:0] ro_final_id;
    
    always @(posedge clk or posedge reset)
    begin 
        if   ( reset )  ro_final_id <= 'h0;
        else            ro_final_id <= r_stored_id;    
    end 
    
    assign o_final_id = ro_final_id;
    
endmodule