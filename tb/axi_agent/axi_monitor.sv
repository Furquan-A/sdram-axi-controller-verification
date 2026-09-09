class axi_monitor extends uvm_monitor;
	`uvm_component_utils(axi_monitor)
	
	virtual axi_if vif;
	
	uvm_analysis_fifo
	function new(string name = "axi_monitor", uvm_component parent);
		super.new(name,parent);
	endfunction 
	
endclass 