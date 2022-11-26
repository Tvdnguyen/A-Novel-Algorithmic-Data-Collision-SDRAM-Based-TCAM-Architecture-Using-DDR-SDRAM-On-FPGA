//////////////////////////////////////////////////////////
//  Category      : Logic Design (TCAM)                 //
//  Name File     : confirm_engine.v                    //
//  Author        : Dang Tieu Binh                      //
//  Email         : dangtieubinh0207@gmail.com          //
//  Standard      : IEEE 1800—2009(Verilog-2009)        //
//  Start design  : 03.10.2022                          //
//  Last revision : 06.10.2022                          //
//			** DO NOT DELETE THIS CONTRIBUTION **		//
//////////////////////////////////////////////////////////

module confirm_engine (
        // clock and reset 
        input                       clk
       ,input                       reset
        
        // data i/o
       ,input   [     KWID-1:0 ]    i_key
       ,input   [    IDWID-1:0 ]    i_id
       ,input   [  MASKWID-1:0 ]    i_maskid
       ,input   [  PRIOWID-1:0 ]    i_priority
       ,input   [     KWID-1:0 ]    i_confirm_key
       
       ,output  [    IDWID-1:0 ] 	o_confirm_ruleid
       ,output  [  PRIOWID-1:0 ]    o_confirm_priority
       
        // control i/o
       ,input                       i_id_update      // inform new ID comes
       ,input                       i_mask_complete
       ,output                      o_confirm_complete
       ,output                      o_confirm_valid
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
    localparam  PRIOWID   = IDWID;
    localparam  KWID      = DATA_BITS;
    localparam  SEGWID    = 2+IDWID+MASKWID+KWID+PRIOWID; // 2-bit status + ID + MASK + KEY + PRIORITY
    localparam  CNFM_WID  = (DATA_BITS/MASKWID);
    
// ===================================================
//	 Input Register
// ===================================================
    
    // Mask Complete Pulse
    
    reg r_mask_complete_sync1;
    
    always @(posedge clk or posedge reset)
    begin 
        if   (reset) r_mask_complete_sync1 <= 0;
        else         r_mask_complete_sync1 <= i_mask_complete;
    end 
    
    wire p_mask_complete;
    assign p_mask_complete = (i_mask_complete & ~r_mask_complete_sync1);
    
    wire p_mask_processing;
    assign p_mask_processing = (~i_mask_complete & r_mask_complete_sync1);
    
    // Data
    
    reg [   KWID-1:0] r_key;
    reg [  IDWID-1:0] r_id;
    reg [MASKWID-1:0] r_maskid;
    reg [   KWID-1:0] r_confirm_key;
    reg [PRIOWID-1:0] r_priority; 
    
    always @(posedge clk or posedge reset)
    begin 
        if (reset) begin 
            r_key         <= 'h0;
            r_id          <= 'h0;
            r_maskid      <= 'h0;
            r_priority    <= 'h0;
            r_confirm_key <= 'h0;
        end 
        else if (p_mask_complete) begin 
            r_key         <= i_key;
            r_id          <= 'h0;
            r_maskid      <= 'h0;
            r_priority    <= 'h0;
            r_confirm_key <= 'h0;
        end 
        else if (i_id_update) begin 
            r_key         <= i_key;
            r_id          <= i_id;
            r_maskid      <= i_maskid;
            r_priority    <= i_priority;
            r_confirm_key <= i_confirm_key;
        end 
        else begin 
            r_key         <= r_key;
            r_id          <= r_id;
            r_maskid      <= r_maskid;
            r_priority    <= r_priority;
            r_confirm_key <= r_confirm_key;
        end 
    end 
    
// ===================================================
//	 Logic Declarations
// ===================================================
    
    // -----------------------------------------------
    //	 Confirmation Process
    // -----------------------------------------------
   
    reg [MASKWID-1:0] r_id_match_vector;
    
    generate 
        genvar mask_idx;
    for (mask_idx = 0; mask_idx < MASKWID; mask_idx=mask_idx+1)
        begin: mask_bit
            always @(posedge clk or posedge reset)
            begin 
                if (reset) begin
                    r_id_match_vector[mask_idx] <= 0;
                end 
                else begin 
                    r_id_match_vector[mask_idx] <= (r_maskid[mask_idx]) ? 1'b1 : (r_confirm_key[(CNFM_WID+(CNFM_WID*mask_idx)-1):(CNFM_WID*mask_idx)] == r_key[(CNFM_WID+(CNFM_WID*mask_idx)-1):(CNFM_WID*mask_idx)]);
                end
            end
        end
    endgenerate
    
    wire w_id_match;
    assign w_id_match = &r_id_match_vector;
    
    // -----------------------------------------------
    //	 ID and Priority
    // ----------------------------------------------- 
    
    reg [  IDWID-1:0] ro_confirm_ruleid;
    reg [PRIOWID-1:0] ro_confirm_priority;
    reg               ro_confirm_valid;
    
    // rule id
    
    always @(posedge clk or posedge reset)
    begin 
        if      ( reset      )  ro_confirm_ruleid <= 'h0;
        else if ( w_id_match )  ro_confirm_ruleid <= r_id;  // Bypass valid ID
        else                    ro_confirm_ruleid <= ro_confirm_ruleid;
    end
    
    // priority
    
    always @(posedge clk or posedge reset)
    begin 
        if      ( reset      )  ro_confirm_priority <= 'h0;
        else if ( w_id_match )  ro_confirm_priority <= r_priority; 
        else                    ro_confirm_priority <= ro_confirm_priority;
    end 
    
    // id valid pulse
    
    always @(posedge clk or posedge reset) 
    begin 
        if      ( reset            )  ro_confirm_valid <= 1'b0;
        else if ( w_id_match       )  ro_confirm_valid <= 1'b1;
        else if ( ro_confirm_valid )  ro_confirm_valid <= 1'b0;
        else                          ro_confirm_valid <= ro_confirm_valid;
    end 
    
    assign o_confirm_ruleid   = ro_confirm_ruleid;
    assign o_confirm_priority = ro_confirm_priority;
    assign o_confirm_valid    = ro_confirm_valid;
    
    // -----------------------------------------------
    //	 Mask Complete
    // -----------------------------------------------
    
    reg ro_confirm_complete; 
    
    always @(posedge clk or posedge reset)
    begin 
        if      ( reset             ) ro_confirm_complete <= 1'b0;
        else if ( p_mask_complete   ) ro_confirm_complete <= 1'b1;
        else if ( p_mask_processing ) ro_confirm_complete <= 1'b0;
        else                          ro_confirm_complete <= ro_confirm_complete;
    end 
    
    assign o_confirm_complete = ro_confirm_complete;
    
endmodule