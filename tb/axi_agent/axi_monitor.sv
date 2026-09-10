class axi_monitor extends uvm_monitor;

    `uvm_component_utils(axi_monitor)

    virtual axi_if.MONITOR vif;

    // Monitor publishes completed AXI transactions
    uvm_analysis_port #(axi_transaction) ap;


    function new(string name = "axi_monitor",
                 uvm_component parent = null);

        super.new(name, parent);

        ap = new("ap", this);

    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db#(virtual axi_if.MONITOR)::get(
                this, "", "vif", vif)) begin

            `uvm_fatal(
                "AXI_MON",
                "Cannot get axi_if from config_db. Was it set?"
            )

        end

    endfunction


    task run_phase(uvm_phase phase);

        /*
         * For now we are monitoring writes only.
         *
         * Later this becomes:
         *
         * fork
         *     begin
         *         forever
         *             monitor_write_transaction();
         *     end
         *
         *     begin
         *         forever
         *             monitor_read_transaction();
         *     end
         * join
         */

        forever begin
            monitor_write_transaction();
        end

    endtask


    task monitor_write_transaction();

        axi_transaction tr;
        int unsigned beats;

        // -----------------------------------------
        // Create a NEW transaction for this burst
        // -----------------------------------------
        tr = axi_transaction::type_id::create("write_tr");

        tr.op = axi_transaction::WRITE;


        // =========================================
        // AW CHANNEL
        // =========================================

        forever begin

            @(vif.mon_cb);

            if (vif.mon_cb.AWVALID &&
                vif.mon_cb.AWREADY) begin

                tr.addr   = vif.mon_cb.AWADDR;
                tr.id     = vif.mon_cb.AWID;
                tr.length = vif.mon_cb.AWLEN;

                tr.burst =
                    axi_transaction::burst_type_e'(
                        vif.mon_cb.AWBURST
                    );

                break;

            end

        end


        // =========================================
        // Allocate W beat storage
        // =========================================

        tr.w_data = new[tr.length + 1];
        tr.wstrb  = new[tr.length + 1];

        beats = 0;


        // =========================================
        // W CHANNEL
        // =========================================

        while (beats < (tr.length + 1)) begin

            @(vif.mon_cb);

            if (vif.mon_cb.WVALID &&
                vif.mon_cb.WREADY) begin

                // Capture one accepted W beat
                tr.w_data[beats] = vif.mon_cb.WDATA;
                tr.wstrb[beats]  = vif.mon_cb.WSTRB;


                // -----------------------------
                // WLAST asserted too early
                // -----------------------------
                if ((beats < tr.length)&&vif.mon_cb.WLAST) 
					begin
						`uvm_error("AXI_MON",$sformatf("WLAST asserted early. Beat=%0d Expected last beat=%0d",beats,tr.length))

					end
                // -----------------------------
                // WLAST missing on final beat
                // -----------------------------
                if ((beats == tr.length) &&
                    !vif.mon_cb.WLAST) begin

                    `uvm_error(
                        "AXI_MON",
                        $sformatf(
                            "WLAST missing on final beat. Beat=%0d",
                            beats
                        )
                    )

                end


                // One handshake = one accepted beat
                beats++;

            end

        end


        // =========================================
        // B CHANNEL
        // =========================================

        forever begin

            @(vif.mon_cb);

            if (vif.mon_cb.BVALID &&
                vif.mon_cb.BREADY) begin


                // Check response ID
                if (vif.mon_cb.BID != tr.id) begin

                    `uvm_error(
                        "AXI_MON",
                        $sformatf(
                            "BID mismatch. AWID=%0d BID=%0d",
                            tr.id,
                            vif.mon_cb.BID
                        )
                    )

                end


                // Capture write response
                tr.bresp =
                    axi_transaction::resp_type_e'(
                        vif.mon_cb.BRESP
                    );

                break;

            end

        end


        // =========================================
        // Complete write transaction
        // =========================================

        `uvm_info(
            "AXI_MON",
            $sformatf(
                "Observed WRITE: ADDR=0x%08h ID=%0d LEN=%0d BURST=%s BRESP=%s",
                tr.addr,
                tr.id,
                tr.length,
                tr.burst.name(),
                tr.bresp.name()
            ),
            UVM_MEDIUM
        )


        // Broadcast completed transaction
        ap.write(tr);

    endtask
	
	task monitor_read_transaction();
		axi_transaction tr;
		tr = axi_transaction::type_id::create("tr);
		
		tr.op = axi_transaction::READ;
		
		// AR Channel 
		forever 
			begin
				@(vif.mon_cb);
				if(vif.mon_cb.ARVALID && vif.mon_cb.ARREADY)
					begin 
						tr.addr = vif.mon_cb.ARADDR;
						tr.id   = vif.mon_cb.ARID;
						tr.lenght = vif.mon_cb.ARLEN;
						tr.burst =axi_transaction::burst_type_e'(vif.mon_cb.ARBURST);
						break;
					end 
			end 
			
		tr.w_data = new[tr.length + 1];
        tr.wstrb  = new[tr.length + 1];
		
		while (beats <tr.lenght+1) 
			begin 
				@(vif.mon_cb);
				if(vif.mon_cb.WVALID && vif.mon_cb.WREADY)
					begin 
						tr.rdata[beats] = vif.mon_cb.RDATA;
						tr.rresp[beats] = axi_transaction::resp_type_e'(vif.mon_cb.RRESP);
						
						// -----------------------------
						// WLAST asserted too early
						// -----------------------------
						if ((beats < tr.length)&&vif.mon_cb.WLAST) 
							begin
								`uvm_error("AXI_MON",$sformatf("WLAST asserted early. Beat=%0d Expected last beat=%0d",beats,tr.length))

							end
						
						 if (vif.mon_cb.RID != tr.id) 
							begin

								`uvm_error(
									"AXI_MON",
									$sformatf(
										"RID mismatch. Expected RID=%0d Received RID=%0d",
										tr.id,
										vif.mon_cb.RID
									)
								)

							end
							
						// RLAST asserted too early
						if ((beats < tr.length) &&
							vif.mon_cb.RLAST) begin

							`uvm_error(
								"AXI_MON",
								$sformatf(
									"RLAST asserted early. Beat=%0d Expected last beat=%0d",
									beats,
									tr.length
								)
							)

						end


						// RLAST missing on final beat
						if ((beats == tr.length) &&
							!vif.mon_cb.RLAST) begin

							`uvm_error(
								"AXI_MON",
								$sformatf(
									"RLAST missing on final beat. Beat=%0d",
									beats
								)
							)

						end


						// One R handshake = one accepted read beat
						beats++;

					end

				end
		
		// =========================================
		// Complete read transaction
		// =========================================

		`uvm_info(
			"AXI_MON",
			$sformatf(
				"Observed READ: ADDR=0x%08h ID=%0d LEN=%0d BURST=%s BEATS=%0d",
				tr.addr,
				tr.id,
				tr.length,
				tr.burst.name(),
				tr.length + 1
			),
			UVM_MEDIUM
		)

endclass