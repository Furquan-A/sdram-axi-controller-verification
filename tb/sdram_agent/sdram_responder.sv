import uvm_pkg::*;
`include "uvm_macros.svh"

class sdram_responder extends uvm_component;

	`uvm_component_utils(sdram_responder)

	virtual sdram_if.RESPONDER vif;

	typedef logic [23:0] sdram_key_t;

	logic [15:0] memory[sdram_key_t];

	logic [12:0] open_row[4];
	bit          row_valid[4];
	bit          auto_precharge_pending[4];


	function new(string name = "sdram_responder", uvm_component parent = null);
		super.new(name,parent);
	endfunction


	function void build_phase(uvm_phase phase);

		super.build_phase(phase);

		if(!uvm_config_db#(virtual sdram_if.RESPONDER)::get(this,"","rsp_if",vif))
			`uvm_fatal("SDRAM_RSP","Cannot get the vif. Did you set it?")

	endfunction


	task run_phase(uvm_phase phase);

		logic [1:0]  bank_index;
		logic [1:0]  bank;

		logic [12:0] row;

		logic [8:0]  column_addr;
		logic [8:0]  column;
		logic [8:0]  second_column;

		sdram_key_t key;

		logic [1:0]  pending_bank;
		logic [12:0] pending_row;
		logic [8:0]  pending_column;

		logic [15:0] write_data[0:1];
		logic [1:0]  write_dqm[0:1];

		bit write_burst_active;
		bit write_beat_count;
		bit sdram_dout_en;
		
		bit read_pending;
		bit read_beat_count;

		int read_delay_count;
		int cas_latency;

		logic [1:0]  pending_read_bank;
		logic [12:0] pending_read_row;
		logic [8:0]  pending_read_column;

		logic [8:0] read_second_column;

		logic [15:0] read_data[0:1];

		sdram_key_t read_key;
		
		logic [2:0] burst_length_code;
		logic [2:0] cas_latency_code;
		int         burst_length;


		super.run_phase(phase);


		for(int i = 0; i < 4; i++)
			begin

				open_row[i]                = '0;
				row_valid[i]               = 0;
				auto_precharge_pending[i] = 0;

			end


		write_burst_active = 0;
		write_beat_count   = 0;

		pending_bank       = '0;
		pending_row        = '0;
		pending_column     = '0;
		
		read_pending         = 0;
		read_beat_count      = 0;
		read_delay_count     = 0;

		pending_read_bank    = '0;
		pending_read_row     = '0;
		pending_read_column  = '0;

		// Temporary until we decode this from the Mode Register
		cas_latency = 2;

		vif.rsp_cb.sdram_data_input <= '0;

		vif.rsp_cb.sdram_data_input <= '0;


		forever
			begin

				@(vif.rsp_cb);


				// ---------------------------------------------------------
				// SECOND WRITE BEAT
				// ---------------------------------------------------------

				if(write_burst_active && write_beat_count)
					begin

						second_column = pending_column + 1;

						write_data[1] = vif.rsp_cb.sdram_data_output;
						write_dqm[1]  = vif.rsp_cb.sdram_dqm;
						sdram_dout_en = vif.rsp_cb.sdram_data_out_en;

						if(!sdram_dout_en)
							`uvm_error("SDRAM_RSP","SDRAM data output enable is 0 during second WRITE beat")


						key = {pending_bank,pending_row,second_column};


						if(write_dqm[1] != 2'b11)
							begin

								if(!memory.exists(key))
									memory[key] = 16'h0000;


								if(!write_dqm[1][0])
									memory[key][7:0] = write_data[1][7:0];


								if(!write_dqm[1][1])
									memory[key][15:8] = write_data[1][15:8];

							end


						$display("WRITE BEAT[1] BANK=%0d ROW=0x%0h COL=0x%0h DATA=0x%0h DQM=%0b ENABLE=%0b",
								 pending_bank,
								 pending_row,
								 second_column,
								 write_data[1],
								 write_dqm[1],
								 sdram_dout_en);


						write_beat_count   = 0;
						write_burst_active = 0;

					end
				
				// ---------------------------------------------------------
				// PENDING SDRAM READ
				// ---------------------------------------------------------

				if(read_pending)
					begin

						// Wait for CAS latency
						if(read_delay_count > 1)
							begin

								read_delay_count--;

							end

						else if(read_delay_count == 1)
							begin

								// -------------------------------------------------
								// READ BEAT 0
								// -------------------------------------------------

								read_key = {
									pending_read_bank,
									pending_read_row,
									pending_read_column
								};


								if(memory.exists(read_key))
									read_data[0] = memory[read_key];
								else
									read_data[0] = 16'h0000;


								vif.rsp_cb.sdram_data_input <= read_data[0];


								$display("READ BEAT[0] BANK=%0d ROW=0x%0h COL=0x%0h DATA=0x%0h",
										 pending_read_bank,
										 pending_read_row,
										 pending_read_column,
										 read_data[0]);


								read_delay_count = 0;
								read_beat_count  = 1;

							end

						else if(read_beat_count)
							begin

								// -------------------------------------------------
								// READ BEAT 1
								// -------------------------------------------------

								read_second_column = pending_read_column + 1;


								read_key = {
									pending_read_bank,
									pending_read_row,
									read_second_column
								};


								if(memory.exists(read_key))
									read_data[1] = memory[read_key];
								else
									read_data[1] = 16'h0000;


								vif.rsp_cb.sdram_data_input <= read_data[1];


								$display("READ BEAT[1] BANK=%0d ROW=0x%0h COL=0x%0h DATA=0x%0h",
										 pending_read_bank,
										 pending_read_row,
										 read_second_column,
										 read_data[1]);


								read_beat_count = 0;
								read_pending    = 0;

							end

					end


				// ---------------------------------------------------------
				// ACTIVE COMMAND
				// CS#=0 RAS#=0 CAS#=1 WE#=1
				// ---------------------------------------------------------

				if(vif.rsp_cb.sdram_cas &&
				   vif.rsp_cb.sdram_we  &&
				  !vif.rsp_cb.sdram_cs  &&
				  !vif.rsp_cb.sdram_ras)
					begin

						bank_index = vif.rsp_cb.sdram_ba;

						open_row[bank_index]  = vif.rsp_cb.sdram_addr;
						row_valid[bank_index] = 1;

						$display("ACTIVE BANK=%0d ROW=0x%0h",
								 bank_index,
								 vif.rsp_cb.sdram_addr);

					end



				// ---------------------------------------------------------
				// PRECHARGE COMMAND
				// CS#=0 RAS#=0 CAS#=1 WE#=0
				// ---------------------------------------------------------

				if(vif.rsp_cb.sdram_cas  &&
				  !vif.rsp_cb.sdram_we   &&
				  !vif.rsp_cb.sdram_cs   &&
				  !vif.rsp_cb.sdram_ras)
					begin


						if(vif.rsp_cb.sdram_addr[10] == 1'b0)
							begin

								bank_index = vif.rsp_cb.sdram_ba;

								row_valid[bank_index]               = 0;
								open_row[bank_index]                = '0;
								auto_precharge_pending[bank_index] = 0;

								$display("PRECHARGE BANK=%0d",bank_index);

							end

						else
							begin

								for(int i = 0; i < 4; i++)
									begin

										open_row[i]                = '0;
										row_valid[i]               = 0;
										auto_precharge_pending[i] = 0;

									end

								$display("PRECHARGE ALL BANKS");

							end

					end



				// ---------------------------------------------------------
				// SDRAM WRITE COMMAND
				// CS#=0 RAS#=1 CAS#=0 WE#=0
				// ---------------------------------------------------------

				if(!vif.rsp_cb.sdram_cas &&
				   !vif.rsp_cb.sdram_we  &&
				   !vif.rsp_cb.sdram_cs  &&
				    vif.rsp_cb.sdram_ras)
					begin

						bank_index = vif.rsp_cb.sdram_ba;

						bank        = bank_index;
						row         = open_row[bank_index];
						column_addr = vif.rsp_cb.sdram_addr[8:0];
						column      = column_addr;


						if(row_valid[bank_index])
							begin

								pending_bank   = bank;
								pending_row    = row;
								pending_column = column;


								key = {bank,row,column};


								write_data[0] = vif.rsp_cb.sdram_data_output;
								write_dqm[0]  = vif.rsp_cb.sdram_dqm;
								sdram_dout_en = vif.rsp_cb.sdram_data_out_en;


								if(!sdram_dout_en)
									`uvm_error("SDRAM_RSP","SDRAM data output enable is 0 during first WRITE beat")


								if(write_dqm[0] != 2'b11)
									begin

										if(!memory.exists(key))
											memory[key] = 16'h0000;


										if(!write_dqm[0][0])
											memory[key][7:0] = write_data[0][7:0];


										if(!write_dqm[0][1])
											memory[key][15:8] = write_data[0][15:8];

									end


								if(vif.rsp_cb.sdram_addr[10])
									auto_precharge_pending[bank_index] = 1;


								$display("WRITE BEAT[0] BANK=%0d ROW=0x%0h COL=0x%0h DATA=0x%0h DQM=%0b ENABLE=%0b",
										 bank,
										 row,
										 column,
										 write_data[0],
										 write_dqm[0],
										 sdram_dout_en);


								write_beat_count   = 1;
								write_burst_active = 1;

							end

						else
							begin

								`uvm_error("SDRAM_RSP",
									$sformatf("WRITE issued to Bank %0d with no active row",bank_index))

							end

					end
					// ---------------------------------------------------------
					// SDRAM READ COMMAND
					// CS#=0 RAS#=1 CAS#=0 WE#=1
					// ---------------------------------------------------------

					if(!vif.rsp_cb.sdram_cas &&
						vif.rsp_cb.sdram_we  &&
					   !vif.rsp_cb.sdram_cs  &&
						vif.rsp_cb.sdram_ras)
						begin

							bank_index = vif.rsp_cb.sdram_ba;

							bank        = bank_index;
							row         = open_row[bank_index];
							column_addr = vif.rsp_cb.sdram_addr[8:0];
							column      = column_addr;


							if(row_valid[bank_index])
								begin

									pending_read_bank   = bank;
									pending_read_row    = row;
									pending_read_column = column;

									read_delay_count = cas_latency;
									read_beat_count  = 0;
									read_pending     = 1;


									if(vif.rsp_cb.sdram_addr[10])
										auto_precharge_pending[bank_index] = 1;


									$display("READ COMMAND BANK=%0d ROW=0x%0h COL=0x%0h CAS_LATENCY=%0d",
											 bank,
											 row,
											 column,
											 cas_latency);

								end

							else
								begin

									`uvm_error("SDRAM_RSP",
										$sformatf("READ issued to Bank %0d with no active row",bank_index))

								end

						end
											

			end

		endtask


endclass