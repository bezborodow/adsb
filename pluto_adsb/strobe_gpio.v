module strobe_gpio (
  input  wire clk,
  //input  wire resetn,     // active-low reset
  output reg  strobe    // goes to the unused header pin
);

  reg [26:0] counter; // enough bits for ~1.34s at 100 MHz

  //always @(posedge clk or negedge resetn) begin
  always @(posedge clk) begin
    //if (!resetn) begin
      //counter  <= 0;
      //strobe <= 0;
    //end else begin
      counter  <= counter + 1;
      strobe <= counter[26]; // toggles at ~0.75 Hz
    //end
  end

endmodule
