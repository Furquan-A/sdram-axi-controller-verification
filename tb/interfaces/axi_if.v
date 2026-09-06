interface axi_if # (
	parameter int ADDR_WIDTH = 32,
	parameter int DATA_WIDTH = 32,
	parameter int ID_WIDTH   = 4,
	parameter int LEN_WIDTH  = 8
	)(
	input logic clk,
	input logic rst_i
	);
	
	// ---- AW Write Address Channel -------
	logic [ADDR_WIDTH-1:0] AWADDR;
	logic                  AWVALID;
	logic				   AWREADY;
	logic [ID_WIDTH-1:0]   AWID;
	logic [LEN_WIDTH-1:0]  AWLEN;
	logic [1:0]            AWBURST;
	
	// --- W WRITE Data Channel ---------
	logic [DATA_WIDTH-1:0]     WDATA;
	logic 				       WVALID;
	logic [(DATA_WIDTH/8)-1:0] WSTRB;
	logic 				       WLAST;
	logic 					   WREADY;
	
	// --- B Write Response Channel -------
	logic [ID_WIDTH-1:0]  BID;
	logic [1:0]           BRESP;
	logic                 BVALID;
	logic                 BREADY;
	
	// --- AR Read Address channel --------
	logic [ADDR_WIDTH-1:0] ARADDR;
	logic [ID_WIDTH-1:0]   ARID;
	logic 				   ARVALID;
	logic 				   ARREADY;
	logic [LEN_WIDTH-1:0]  ARLEN;
	logic [1:0] 		   ARBURST;
	
	// -- R Read Data Channel ------------
	logic [DATA_WIDTH-1:0] RDATA;
	logic [ID_WIDTH-1:0]   RID;
	logic [1:0]     	   RRESP;
	logic 				   RLAST;
	logic   			   RVALID;
	logic				   RREADY;
	
	// Clocking skew:
	// input #1step : sample DUT signals just before clock edge,
	//                helps avoid DUT/TB sampling races.
	// output #0    : drive TB signals at the clocking event
	//                using clocking-block scheduling.
	// Default applies to all CB signals unless individually overridden.
	// NOTE: #1step is NOT the same as #1 time unit.
	
default input #1step output #0;
	clocking drv_cb @(posedge clk);
		default input #1step output #0;
		
		output AWADDR,AWVALID,AWLEN,AWBURST,AWID;
		output WDATA,WLAST,WVALID,WSTRB;
		output BREADY;
		output ARADDR,ARVALID,ARBURST,ARLEN,ARID;
		output RREADY;
		
		input AWREADY,WREADY,ARREADY,BRESP,BID,BVALID;
		input RDATA,RVALID,RID,RLAST,RRESP;
		
	endclocking
	
	clocking mon_cb @(posedge clk);

		default input #1step output #0;

		input AWADDR, AWVALID, AWLEN, AWBURST, AWID, AWREADY;
		input WDATA, WLAST, WVALID, WSTRB, WREADY;
		input BRESP, BID, BVALID, BREADY;
		input ARADDR, ARVALID, ARBURST, ARLEN, ARID, ARREADY;
		input RDATA, RVALID, RID, RLAST, RRESP, RREADY;

	endclocking
	
	
	modport DRIVER (
		clocking drv_cb,
		input rst_i
	);

	modport MONITOR (
		clocking mon_cb,
		input rst_i
	);
	
	modport DUT (
		input clk,
		input rst_i,
		input  AWADDR, AWVALID, AWLEN, AWBURST, AWID,
		input  WDATA, WLAST, WVALID, WSTRB,
		input  BREADY,
		input  ARADDR, ARVALID, ARBURST, ARLEN, ARID,
		input  RREADY,

		output AWREADY, WREADY,
		output BRESP, BID, BVALID,
		output ARREADY,
		output RDATA, RVALID, RID, RLAST, RRESP
	);
endinterface

// ============================================================
// AXI INTERFACE NOTES
// ============================================================
//
// 1. Interface groups related AXI signals in one place.
//    It avoids passing individual signals separately through TB code.
//
// 2. Signal directions depend on the point of view.
//    AXI Master drives requests/data.
//    AXI Slave/DUT drives READY and response/data signals.
//
// 3. Driver clocking block:
//    - OUTPUT = signals driven by the testbench/master
//    - INPUT  = signals sampled from the DUT/slave
//
// 4. Monitor clocking block:
//    - All signals are INPUT because the monitor is passive.
//    - Monitor must never drive DUT signals.
//
// 5. Clocking blocks define:
//    - when TB signals are driven/sampled relative to the clock
//    - TB-side input/output direction
//    - help avoid DUT/TB race conditions
//
// 6. Prefer:
//       default input #1step output #0;
//    instead of arbitrary #1 delays.
//
// 7. Modports provide a restricted view of the interface.
//    DRIVER modport exposes drv_cb.
//    MONITOR modport exposes mon_cb.
//
// 8. DUT does not normally need a clocking block.
//    RTL already synchronizes itself using always @(posedge clk).
//
// 9. DUT modport, if used, has directions opposite to the AXI
//    master/driver because our DUT is an AXI slave.
//
// 10. Master-driven signals:
//     AWADDR, AWID, AWLEN, AWBURST, AWVALID
//     WDATA, WSTRB, WLAST, WVALID
//     BREADY
//     ARADDR, ARID, ARLEN, ARBURST, ARVALID
//     RREADY
//
// 11. DUT-driven signals:
//     AWREADY
//     WREADY
//     BID, BRESP, BVALID
//     ARREADY
//     RID, RDATA, RRESP, RLAST, RVALID
//
// 12. AXI transfer happens only when:
//        VALID && READY
//     at the active clock edge.
//
// 13. While VALID=1 and READY=0, the source must keep
//     VALID and its payload stable until handshake.
//
// 14. Keep widths parameterized whenever possible.
//     Example:
//       WSTRB width = DATA_WIDTH / 8
//
// ============================================================