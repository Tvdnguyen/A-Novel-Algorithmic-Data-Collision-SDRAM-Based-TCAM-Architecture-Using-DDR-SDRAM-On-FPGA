//////////////////////////////////////////////////////////
//  Category      : Logic Design (TCAM)                 //
//  Name File     : mask_engine.v                       //
//  Author        : Dang Tieu Binh                      //
//  Email         : dangtieubinh0207@gmail.com          //
//  Standard      : IEEE 1800—2009(Verilog-2009)        //
//  Start design  : 03.10.2022                          //
//  Last revision : 06.10.2022                          //
//          ** DO NOT DELETE THIS CONTRIBUTION **       //
//////////////////////////////////////////////////////////

module mask_engine (
        // clock and reset 
        input                         clk
       ,input                         reset
        
        // data i/o
       ,input       [  SEGWID-1:0 ]   i_sdram_readdata    
       ,output      [   IDWID-1:0 ]   o_id
       ,output      [ MASKWID-1:0 ]   o_maskid
       ,output      [    KWID-1:0 ]   o_confirm_key
       ,output      [ PRIOWID-1:0 ]   o_priority
        
        // control i/o
       ,input                         i_cntl_s0_searchdatavalid
       ,input                         i_segment_complete
       ,output                        o_id_update
       ,output                        o_mask_complete
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
    localparam 	KWID	  = DATA_BITS;
    localparam 	SEGWID	  = 2+IDWID+MASKWID+KWID+PRIOWID; // 2-bit status + ID + MASK + KEY + PRIORITY

// ===================================================
//	 Input Register
// ===================================================
    
    // Data
    
    reg               r_id_valid;
    reg [  IDWID-1:0] r_id;
    reg [MASKWID-1:0] r_maskid;
    reg [   KWID-1:0] r_confirm_key;
    reg [PRIOWID-1:0] r_priority;
    
    always @(posedge clk or posedge reset)
    begin 
        if (reset) begin 
            r_id_valid    <= 'h0;
            r_id          <= 'h0;
            r_maskid      <= 'h0;
            r_priority    <= 'h0;
            r_confirm_key <= 'h0;
        end
        else if (i_cntl_s0_searchdatavalid) begin
            r_id_valid    <= (~i_sdram_readdata[SEGWID-1] & i_sdram_readdata[SEGWID-2]); // 01
            r_id          <= i_sdram_readdata[       SEGWID-3:KWID+MASKWID ];
            r_maskid      <= i_sdram_readdata[ KWID+MASKWID-1:KWID         ];
            r_confirm_key <= i_sdram_readdata[         KWID-1:PRIOWID      ];
            r_priority    <= i_sdram_readdata[      PRIOWID-1:0            ];
        end 
    end
    
    // Data valid Pulse 
    
    reg r_searchdatavalid_sync1;
    
    always @(posedge clk or posedge reset)
    begin 
        if (reset)  r_searchdatavalid_sync1 <= 0;
        else        r_searchdatavalid_sync1 <= i_cntl_s0_searchdatavalid;
    end 
    
    wire p_searchdatavalid; 
    assign p_searchdatavalid = (i_cntl_s0_searchdatavalid & ~r_searchdatavalid_sync1);
    
    // Segment Complete Pulse 
    
    reg r_segment_complete_sync1;
    
    always @(posedge clk or posedge reset)
    begin 
        if   (reset) r_segment_complete_sync1 <= 0;
        else         r_segment_complete_sync1 <= i_segment_complete;
    end 
    
    wire p_segment_complete;
    assign p_segment_complete = (i_segment_complete & ~r_segment_complete_sync1);
    
    wire p_segment_processing;
    assign p_segment_processing = (~i_segment_complete & r_segment_complete_sync1);
    
// ===================================================
//	 Logic Declarations
// ===================================================

    // -----------------------------------------------
    //	 Process
    // -----------------------------------------------
    
    reg [        1:0] ro_id_valid;
    reg [  IDWID-1:0] ro_id;
    reg [MASKWID-1:0] ro_maskid;
    reg [   KWID-1:0] ro_confirm_key;
    reg [PRIOWID-1:0] ro_priority;
    
    always @(posedge clk or posedge reset)
    begin 
        if (reset) begin 
            ro_id          <= 'h0;
            ro_maskid      <= 'h0;
            ro_priority    <= 'h0;
            ro_confirm_key <= 'h0;
        end
        else if (p_segment_complete) begin 
            ro_id          <= 'h0;
            ro_maskid      <= 'h0;
            ro_priority    <= 'h0;
            ro_confirm_key <= 'h0;
        end
        else if (r_id_valid) begin 
            ro_id          <= r_id;
            ro_maskid      <= r_maskid;
            ro_priority    <= r_priority;
            ro_confirm_key <= r_confirm_key;
        end  
        else begin 
            ro_id          <= ro_id;
            ro_maskid      <= ro_maskid;
            ro_priority    <= ro_priority;
            ro_confirm_key <= ro_confirm_key;
        end 
    end
    
    assign o_id          = ro_id;            
    assign o_maskid      = ro_maskid;     
    assign o_priority    = ro_priority;   
    assign o_confirm_key = ro_confirm_key;
   
    // -----------------------------------------------
    //	 ID Update Signal
    // -----------------------------------------------
    
    wire w_new_id;
    assign w_new_id = ~p_segment_complete & p_searchdatavalid & r_id_valid;
    
    reg ro_id_update;
    
    always @(posedge clk or posedge reset)
    begin 
        if      ( reset        )  ro_id_update <= 1'b0;
        else if ( w_new_id     )  ro_id_update <= 1'b1;
        else if ( ro_id_update )  ro_id_update <= 1'b0;
        else                      ro_id_update <= ro_id_update;
    end 
    
    assign o_id_update = ro_id_update;
    
    // -----------------------------------------------
    //	 Mask Complete
    // ----------------------------------------------- 
    
    reg ro_mask_complete;
    
    always @(posedge clk or posedge reset)
    begin 
        if      ( reset                )  ro_mask_complete <= 1'b0;
        else if ( p_segment_complete   )  ro_mask_complete <= 1'b1;
        else if ( p_segment_processing )  ro_mask_complete <= 1'b0;
        else                              ro_mask_complete <= ro_mask_complete;
    end
    
    assign o_mask_complete = ro_mask_complete;
    
endmodule