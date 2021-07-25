//#############################################################################
//# Function: Synchronous FIFO                                                #
//#############################################################################
//# Author:   Andreas Olofsson                                                #
//# License:  MIT (see LICENSE file in OH! repository)                        #
//#############################################################################

module oh_fifo_sync
  #(parameter DW       = 104,          // FIFO width
    parameter DEPTH    = 32,           // FIFO depth
    parameter REG      = 1,            // Register fifo output
    parameter SYNCPIPE = 2,            // depth of synchronization pipeline
    parameter SYN      = "true",       // synthesizable
    parameter TYPE     = "default",    // implementation type
    parameter SHAPE    = "square",     // hard macro shape (square, tall, wide),
    parameter PROGFULL = DEPTH-1,      // programmable almost full level
    parameter AW       = $clog2(DEPTH) // count width (derived)
    )
   (
    //basic interface
    input 		clk, // clock
    input 		nreset, //async reset
    input 		clear, //clear fifo (synchronous)
    //write port
    input 		wr_clk,
    input [DW-1:0] 	wr_din, // data to write
    input 		wr_en, // write fifo
    output 		wr_full, // fifo full
    output 		wr_almost_full, //one entry left
    output 		wr_prog_full, //programmable full level
    output reg [AW-1:0] wr_count, // pessimistic report of entries from wr side
    //read port
    input 		rd_clk,
    output [DW-1:0] 	rd_dout, // output data (next cycle)
    input 		rd_en, // read fifo
    output 		rd_empty, // fifo is empty
    // BIST interface
    input 		bist_en, // bist enable
    input 		bist_we, // write enable global signal
    input [DW-1:0] 	bist_wem, // write enable vector
    input [AW-1:0] 	bist_addr, // address
    input [DW-1:0] 	bist_din, // data input
    input [DW-1:0] 	bist_dout, // data input
    // Power/repair (hard macro only)
    input 		shutdown, // shutdown signal
    input 		vss, // ground signal
    input 		vdd, // memory array power
    input 		vddio, // periphery/io power
    input [7:0] 	memconfig, // generic memory config
    input [7:0] 	memrepair // repair vector
    );

   //############################
   //local wires
   //############################
   reg [AW:0]          wr_addr;
   reg [AW:0]          rd_addr;
   reg 		       empty_reg;
   wire 	       fifo_read;
   wire 	       fifo_write;
   wire 	       ptr_match;
   wire 	       fifo_empty;

   //#########################################################
   // FIFO Control
   //#########################################################

   assign fifo_read   = rd_en & ~rd_empty;
   assign fifo_write  = wr_en & ~wr_full;
   assign almost_full = (wr_count[AW-1:0] == PROGFULL);
   assign ptr_match   = (wr_addr[AW-1:0] == rd_addr[AW-1:0]);
   assign full        = ptr_match & (wr_addr[AW]==!rd_addr[AW]);
   assign fifo_empty  = ptr_match & (wr_addr[AW]==rd_addr[AW]);

   always @ (posedge clk or negedge nreset)
     if(~nreset)
       begin
          wr_addr[AW:0]    <= 'd0;
          rd_addr[AW:0]    <= 'b0;
          wr_count[AW-1:0] <= 'b0;
       end
     else if(clear)
       begin
          wr_addr[AW:0]    <= 'd0;
          rd_addr[AW:0]    <= 'b0;
          wr_count[AW-1:0] <= 'b0;
       end
     else if(fifo_write & fifo_read)
       begin
	  wr_addr[AW:0] <= wr_addr[AW:0] + 'd1;
	  rd_addr[AW:0] <= rd_addr[AW:0] + 'd1;
       end
     else if(fifo_write)
       begin
	  wr_addr[AW:0]    <= wr_addr[AW:0] + 'd1;
	  wr_count[AW-1:0] <= wr_count[AW-1:0] + 'd1;
       end
     else if(fifo_read)
       begin
          rd_addr[AW:0]    <= rd_addr[AW:0] + 'd1;
          wr_count[AW-1:0] <= wr_count[AW-1:0] - 'd1;
       end

   //Pipeline register to account for RAM output register
   always @ (posedge clk)
     empty_reg <= fifo_empty;

   assign empty = (REG==1) ? empty_reg : fifo_empty;

   //###########################
   //# Memory Array
   //###########################

   oh_memory_dp #(.DW(DW),
		  .DEPTH(DEPTH),
		  .REG(REG),
		  .SYN(SYN),
		  .TYPE(TYPE),
		  .SHAPE(SHAPE))
   oh_memory_dp(.wr_wem			({(DW){1'b1}}),
		/*AUTOINST*/
		// Outputs
		.rd_dout		(rd_dout[DW-1:0]),
		// Inputs
		.wr_clk			(wr_clk),
		.wr_en			(wr_en),
		.wr_addr		(wr_addr[AW-1:0]),
		.wr_din			(wr_din[DW-1:0]),
		.rd_clk			(rd_clk),
		.rd_en			(rd_en),
		.rd_addr		(rd_addr[AW-1:0]),
		.bist_en		(bist_en),
		.bist_we		(bist_we),
		.bist_wem		(bist_wem[DW-1:0]),
		.bist_addr		(bist_addr[AW-1:0]),
		.bist_din		(bist_din[DW-1:0]),
		.shutdown		(shutdown),
		.vss			(vss),
		.vdd			(vdd),
		.vddio			(vddio),
		.memconfig		(memconfig[7:0]),
		.memrepair		(memrepair[7:0]));

endmodule // oh_fifo_sync

// Local Variables:
// verilog-library-directories:("." "../dv" "../../fpu/hdl" "../../../oh/common/hdl")
// End:
