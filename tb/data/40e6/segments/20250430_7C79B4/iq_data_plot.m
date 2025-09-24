% Simple time-domain IQ plot.
% From GNU Radio file sink: interleaved float32 I,Q.
fname = 'cap1/seg16_truncated';
fs = 40e6; % sample rate: 40 MSPS
fid = fopen(fname,'rb');
raw = fread(fid, 'float32=>double');   % interleaved I,Q as float32
fclose(fid);

% Separate I and Q and form complex vector.
I = raw(1:2:end);
Q = raw(2:2:end);
IQ = I + 1j.*Q;
N = numel(IQ);

t = (0:N-1).' / fs;

figure;
plot(t, real(IQ)); hold on
plot(t, imag(IQ));
xlabel('Time (s)');
ylabel('Amplitude');
legend('I','Q');
title(sprintf('IQ time-domain — %d samples, fs=%.0f Hz', N, fs));
grid on;

