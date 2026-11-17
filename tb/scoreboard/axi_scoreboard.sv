class axi_scoreboard extends uvm_scoreboard;
	`uvm_component_utils(axi_scoreboard)
	
	logic [31:0] expected_mem [bit [31:0]];
	bit [3:0] byte_valid [bit [31:0]];

	function new(string name = "axi_scoreboard", uvm_component parent = null);
		super.new(name,parent);
	endfunction 
	
	/*function void update memory(input logic [31:0] addr, input logic [31:0] wdata, input logic [3:0] wstrb);
	
	if(!expected_mem.exists(addr))
		`uvm_warning("AXI_SB",$sformatf("No expected data available at address 0x%08h",addr))
	else // is the addr exists 
		begin 
			for(int i=0; i<$bits(wdata)/8; i++)
				begin 
					if(byte_valid[addr] == 4'b0000)
						`uvm_info("AXI_SB",$sformat("No data available to compare at address = %0h.",addr),UVM_MEDIUM)
						
						else if(byte_valid[addr][i])
							begin 
								if(expected_mem[addr][8*i +: 8] !== wdata[8*i +: 8])
									`uvm_fatal("AXI_SB",$sformat("MISMATCH: At addr = %0h, expected_data = %0h, actual_data = %0h"
													,addr,expected_mem[addr][8*i +: 8],wdata[8*i +: 8]))
								else 
									`uvm_info("AXI_SB",$sformat("MATCH:At addr = %0h, expected_data = %0h, actual_data = %0h"
													,addr,expected_mem[addr][8*i +: 8],wdata[8*i +: 8]),UVM_MEDIUM)
							end 
				end
		end
	
	endfunction*/
	
	function void update_memory(input logic [31:0] addr, input logic [31:0] wdata, input logic [3:0] wstrb);
	
		if(!expected_mem.exists(addr))
			begin 	
				expected_mem[addr] = 'x;
				byte_valid[addr] = '0;
			end
		for(int i=0; i<$bits(wdata)/8; i++)
			begin
				if(wstrb[i])
					begin 
						expected_mem[addr][8*i +: 8] = wdata[8*i +: 8];
						byte_valid[addr][i] = wstrb[i];
					end 
			end 
			
	endfunction
	
	function void check_read(input logic [31:0] addr, input logic [31:0] actual_rdata);

		if(!expected_mem.exists(addr))
			`uvm_warning("AXI_SB",$sformatf("Read comparison skipped: Address = %0h",addr))

		else if(byte_valid[addr] == 4'b0000)
			`uvm_warning("AXI_SB",$sformatf("No valid bytes available at address = %0h",addr))

		else
			begin
				for(int i=0; i<$bits(actual_rdata)/8; i++)
					begin
						if(byte_valid[addr][i])
							begin
								if(expected_mem[addr][8*i +: 8] !== actual_rdata[8*i +: 8])
									`uvm_error("AXI_SB",$sformatf("Mismatch: Addr=%0h, Byte=%0d, Expected=%0h, Actual=%0h",addr,i,expected_mem[addr][8*i +: 8],actual_rdata[8*i +: 8]))
							end
					end
			end

	endfunction
	
endclass 	