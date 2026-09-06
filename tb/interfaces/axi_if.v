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
	logic [ID_WIDTH-1:0] BID;
	logic [ID_WIDTH-1:0] BID;
	logic [1:0]           BRESP;
	logic                 BVALID;
	logic                 BREADY;
	
