% WARNING: this function is not part of the EEGLAB toolbox and should not be distributed
%           you must contact Arnaud Delorme (arno@salk.edu) for terms of use
%
% newcrossf() - Returns estimates and plots event-related coherence (ERCOH) 
%        between two input data time series. A lower panel (optionally) shows 
%        the coherence phase difference between the processes. In this panel: 
%           -90 degrees (blue)   means x leads y by a quarter cycle.
%            90 degrees (orange) means y leads x by a quarter cycle.
%        Click on any subplot to view separately and zoom in/out.
%
% Function description:
%        Uses EITHER fixed-window, zero-padded FFTs (fastest) OR constant-Q 
%        0-padded wavelet DFTs (more even sensitivity across frequencies), 
%        both Hanning-tapered.  Output frequency spacing is the lowest 
%        frequency ('srate'/'winsize') divided by the 'padratio'.
%
%        If an 'alpha' value is given, then bootstrap statistics are 
%        computed (from a distribution of 'naccu' (200) surrogate baseline
%        data epochs) for the baseline epoch, and non-significant features 
%        of the output plots are zeroed (and shown in green). The baseline
%        epoch is all windows with center latencies < the given 'baseline' value 
%        or, if 'baseboot' is 1, the whole epoch. 
% Usage: 
%        >> [coh,mcoh,timesout,freqsout,cohboot,cohangles,...
%                  allcoher,alltfX,alltfY] = crossf(x,y,frames,tlimits,srate, ...
%                                        cycles, 'key1', 'val1', 'key2', val2' ...);
%
% Required inputs:
%       x       = First single-channel data set (1,frames*nepochs)      
%                 Else, cell array {x1,x2} of two such data vectors to also
%                 estimate (significant) coherence differences between two 
%                 conditions.
%       y       = Second single-channel data set (1,frames*nepochs)     
%                 Else, cell array {y1,y2} of two such data vectors.
%       frames  = Frames per epoch                                   {750}
%       tlimits = [mintime maxtime] (ms) Epoch latency limits  {[-1000 2000]}
%       srate   = Data sampling rate (Hz)                            {250}
%       cycles  = 0  -> Use FFTs (with constant window length) 
%               = >0 -> Number of cycles in each analysis wavelet 
%               = [cycles expfactor] -> if 0 < expfactor < 1,  the number 
%                 of wavelet cycles expands with frequency from cycles
%                 If expfactor = 1, no expansion; if = 0, constant
%                 window length (as in FFT)            {default cycles: 0}
%
%    Optional Coherence Type:
%       'type'  = ['coher'|'phasecoher'|'amp'] Compute either linear coherence
%                 ('coher'), phase coherence ('phasecoher') also known
%                 as phase coupling factor', or amplitude correlations ('amp')
%                 {default: 'phasecoher'}. Note that for amplitude correlation,
%                 the significance threshold is computed using the corrcoef
%                 function, so can be set arbitrary low without increase in
%                 computation load. An additional type is 'crossspec' to compute
%                 cross-spectrum between 2 processes (single-trial). This type
%                 is automatically selected if user enter continuous data.
%       'amplag' = [integer vector] allow to compute non 0 amplitude correlation 
%                 (using option 'amp' above). The vector given as parameter 
%                 indicates the point lags ([-4 -2 0 2 4] would compute the 
%                 correlation at time t-4, t-2, t, t+2, t+4, and return the 
%                 maximum correlation at these points).
%       'subitc' = ['on'|'off'] Subtract stimulus locked Inter-Trial Coherence 
%                 from x and y. This computes the  'intrinsic' coherence
%                 x and y not arising from common synchronization to 
%                 experimental events. For cell array input, one may provide
%                 a cell array ({'on','off'} for example). {default: 'off'}
%       'shuffle' = Integer indicating the number of estimates to compute
%                 bootstrap coherence based on shuffled trials. This estimates
%                 the coherence arising only from time locking of x and y
%                 to experimental events (opposite of 'subitc'). For cell array 
%                 input, one may provide a cell array, for exemple { 1 0 }.
%                 { default 0: no shuffling }.
%
%    Optional Detrend:
%       'detrend'   = ['on'|'off'], Linearly detrend each data epoch   {'off'}
%       'rmerp'     = ['on'|'off'], Remove epoch mean from data epochs {'off'}
%
%    Optional FFT/DFT:
%       'winsize'   = If cycles==0: data subwindow length (fastest, 2^n<frames);
%                     if cycles >0: *longest* window length to use. This
%                     determines the lowest output frequency  {~frames/8}
%       'timesout'  = Number of output latencies (int<frames-winframes). {200) 
%                     A negative value (-S) subsamples the original latencies 
%                     by S. An array of latencies computes spectral 
%                     decompositions at specific latency values (Note: the 
%                     algorithm finds the closest latencies in the data, 
%                     possibly resulting in slightly unevenly spaced 
%                     output latencies. 
%       'padratio'  = FFT-length/winframes (2^k)                    {2}
%                     Multiplies the number of output frequencies by dividing
%                     their spacing (standard FFT padding). When cycles~=0, 
%                     frequency spacing is divided by padratio.
%       'maxfreq'   = Maximum frequency (Hz) to plot (& output if cycles>0) 
%                     If cycles==0, all FFT frequencies are output.{def: 50}
%                     Note: NOW DEPRECATED, use 'freqs' instead,
%       'freqs'     = [min max] Frequency limits. {Default: [minfreq 50],
%                     minfreq being determined by the number of data points, 
%                     cycles and sampling frequency}.
%       'nfreqs'    = Number of output frequencies. For FFT, closest computed
%                     frequency will be returned. Overwrite 'padratio' effects
%                     for wavelets. {Default: use 'padratio'}.
%       'freqscale' = ['log'|'linear'] Frequency scaling. {Default: 'linear'}.
%                     Note that for obtaining 'log' spaced freqs using FFT, 
%                     closest correspondant frequencies in the 'linear' space 
%                     are returned.
%       'baseline'  = Spectral baseline end-time (in ms). NaN imply that no
%                      baseline is used. A range [min max] may also be entered
%                     You may also enter one row per region for baseline
%                     e.g. [0 100; 300 400] considers the window 0 to 100 ms and
%                     300 to 400 ms. This is only valid for the coherence amplitude
%                     not for the coherence phase. { default NaN }
%       'lowmem'    = ['on'|'off'] {'off'} Compute frequency by frequency to 
%                     save memory. 
%
%    Optional Bootstrap:
%       'alpha'    = If non-0, compute two-tailed bootstrap significance prob.
%                    level. Show non-signif output values in neutral green. {0}
%       'naccu'    = Number of bootstrap replications to compute {200}
%       'boottype' = ['times'|'timestrials'|'trials'] Bootstrap type: Either 
%                    shuffle windows ('times') or windows and trials ('timestrials')
%                    or trials only using a separate bootstrap for each time window
%                    ('trials'). Option 'times' is not recommended but requires 
%                    less memory and provide similar results to other options.
%                    {default: 'timestrials'}
%       'baseboot'  = Bootstrap baseline subtract (1 -> use 'baseline';
%                                                  0 -> use whole trial
%                                                  [min max] -> use time range)
%                     Default is to use the baseline unless no baseline is
%                     specified (then the function uses all sample up to time 0)
%                     You may also enter one row per region for baseline
%                     e.g. [0 100; 300 400] considers the window 0 to 100 ms and
%                     300 to 400 ms.
%       'condboot' = ['abs'|'angle'|'complex'] In comparing two conditions,
%                    either subtract complex spectral values' absolute vales 
%                    ('abs'), angles ('angles') or the complex values themselves
%                    ('complex').     {default: 'abs'}
%       'rboot'    = Input bootstrap coherence limits (e.g., from crossf()) 
%                    The bootstrap type should be identical to that used
%                    to obtain the input limits. {default: compute from data}
% Optional scalp map:
%       'topovec'  = (2,nchans) matrix. Scalp maps to plot {[]}
%                    ELSE [c1,c2], plot two cartoons showing channel locations.
%       'elocs'    = Electrode location file for scalp map       {none}
%                    File should be ascii in format of >> topoplot example   
%
% Optional plot and compute features:
%       'compute'   = ['matlab'|'C'] Use C sub-routine to speed up the
%                     computation                      {default 'matlab'}
%       'plotamp'   = ['on'|'off']. Plot coherence magnitude       {'on'}
%       'maxamp'    = [real] Set the maximum for the amplitude scale {auto}
%       'plotphase' = ['on'|'off']. Plot coherence phase angle     {'on'}
%       'angleunit' = Phase units: 'ms' for msec or 'deg' for degrees {'deg'}
%       'title'     = Optional figure title. If two conditions are given
%                     as input, title can be a cell array with two text
%                     string elements {none}
%       'vert'      = Latencies to mark with a dotted vertical line   {none}
%       'linewidth' = Line width for marktimes traces (thick=2, thin=1) {2}
%       'newfig'    = ['on'|'off'] Create new figure for difference plots {'on'}
%       'axesfont'  = Axes font size                               {10}
%       'titlefont' = Title font size                              {8}
%
% Outputs: 
%       coh         = Matrix (nfreqs,timesout) of coherence magnitudes 
%       mcoh        = Vector of mean baseline coherence at each frequency
%                     see 'baseline' parameter.
%       timesout    = Vector of output latencies (window centers) (ms).
%       freqsout    = Vector of frequency bin centers (Hz).
%       cohboot     = Matrix (nfreqs,2) of [lower;upper] coher signif. limits
%                     if 'boottype' is 'trials',  (nfreqs,timesout, 2)
%       cohangle    = (nfreqs,timesout) matrix of coherence angles 
%       allcoher    = single trial coherence
%       alltfX      = single trial spectral decomposition of X
%       alltfY      = single trial spectral decomposition of Y
%
% Notes: 1) When cycles==0, nfreqs is total number of FFT frequencies.
%        2) 'blue' coherence lag -> x leads y; 'red' -> y leads x
%        3) The 'boottype' should be ideally 'timestrials', but this creates 
%           large memory demands, so 'times' must be used in many cases.
%        4) If 'boottype' is 'trials', the average of the complex bootstrap
%           is subtracted from the coherence to compensate for phase differences
%           (the average is also subtracted from the bootstrap distribution). 
%           For other bootstraps, this is not necessary since there the phase 
%           distribution should be random.
%        5) If baseline is non-NaN, the baseline is subtracted from
%           the complex coherence. On the left hand side of the coherence
%           amplitude image, the baseline is displayed as a magenta line.
%           (If no baseline is selected, this curve represents the average
%           coherence at every given frequency).
%
% Authors: Arnaud Delorme, Sigurd Enghoff & Scott Makeig
%          CNL/Salk Institute 1998-2001; SCCN/INC/UCSD, La Jolla, 2002-
%
% See also: timef()

% NOTE: one hidden parameter 'savecoher', 0 or 1

% Copyright (C) 8/1/98  Arnaud Delorme, Sigurd Enghoff & Scott Makeig, SCCN/INC/UCSD
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

% $Log: not supported by cvs2svn $
% Revision 1.68  2004/06/02 18:25:07  arno
% implementing crossspec option
%
% Revision 1.67  2004/04/29 17:43:57  arno
% debug scaling for amp
%
% Revision 1.66  2004/04/29 16:55:26  arno
% implementing amplitude correlation
%
% Revision 1.65  2004/04/29 00:59:28  arno
% implementing amplitude correlation
%
% Revision 1.64  2003/11/26 18:10:22  scott
% help message
%
% Revision 1.63  2003/10/15 18:46:01  arno
% *** empty log message ***
%
% Revision 1.62  2003/08/08 22:25:28  arno
% *** empty log message ***
%
% Revision 1.61  2003/08/04 16:22:00  arno
% marginal plot colors
%
% Revision 1.60  2003/07/09 21:30:54  arno
% timesout - > ntimesout for timefreq call
%
% Revision 1.59  2003/06/27 01:01:32  arno
% updating timesout help
%
% Revision 1.58  2003/06/21 01:08:24  arno
% reshaping Rdiff if one freq output
%
% Revision 1.57  2003/05/29 15:00:32  arno
% debug lowmem option
%
% Revision 1.56  2003/05/29 00:23:00  arno
% debug last
%
% Revision 1.55  2003/05/29 00:17:24  arno
% allow 3D inputs
%
% Revision 1.54  2003/05/24 19:10:57  arno
% debug lowmem
%
% Revision 1.53  2003/05/23 17:15:35  arno
% lowmem for 2 conditions debug
%
% Revision 1.52  2003/05/22 01:21:32  arno
% detrending param name change
%
% Revision 1.51  2003/05/21 02:06:34  arno
% debug for conditions
%
% Revision 1.50  2003/05/20 22:29:03  arno
% lowmem for 2condition debug
%
% Revision 1.49  2003/05/19 23:54:12  arno
% lowmem for condstat
%
% Revision 1.48  2003/05/19 23:00:10  arno
% debug last
%
% Revision 1.47  2003/05/19 22:55:47  arno
% implementing lowmem option for bootstrap
%
% Revision 1.46  2003/05/02 21:47:07  arno
% implementing lowmem option
%
% Revision 1.45  2003/05/01 22:03:17  arno
% debuging frequencies
%
% Revision 1.44  2003/05/01 00:46:33  arno
% updating outputs
%
% Revision 1.43  2003/05/01 00:11:16  arno
% removing dispf
%
% Revision 1.42  2003/04/17 21:21:35  arno
% fixing newfig
%
% Revision 1.41  2003/04/17 18:06:05  arno
% adding newfig option
%
% Revision 1.40  2003/01/09 16:00:31  arno
% correcting typo
%
% Revision 1.39  2003/01/06 19:41:52  arno
% implementing new bootstrap type
%
% Revision 1.38  2003/01/06 18:11:40  arno
% shuffle along the 3rd dimension
%
% Revision 1.37  2003/01/06 17:45:52  arno
% adding shuffle for conditions
%
% Revision 1.36  2003/01/04 02:43:28  arno
% catch error for fully non-significan image
%
% Revision 1.35  2003/01/04 02:16:21  arno
% implementing optional different subitc option for different conditions
%
% Revision 1.34  2003/01/02 21:24:02  cooper
% more fixes to lin coher formula.
%
% Revision 1.33  2003/01/02 19:59:33  arno
% remove phase inversion for wavelets
%
% Revision 1.32  2003/01/02 09:08:41  cooper
% fixed bug in formula for linear
% coherence passed to condstat.
%
% Revision 1.31  2003/01/02 07:35:10  cooper
% fixed coherresout = [] bug in
% linear coher case.
%
% Revision 1.30  2003/01/02 04:17:09  cooper
% fixed a couple of typos
%
% Revision 1.29  2002/12/04 22:32:15  arno
% trying to debug tites for multiple conditions
%
% Revision 1.28  2002/11/20 15:51:21  arno
% do not return abs Rdiff
%
% Revision 1.27  2002/11/20 02:04:45  arno
% debugging ??? One or more output arguments not assigned during call to 'newcrossf'.
%
% Revision 1.26  2002/11/20 01:44:06  arno
% same
%
% Revision 1.25  2002/11/20 01:41:23  arno
% do not plot for crossfdiff
%
% Revision 1.24  2002/11/20 01:13:47  arno
% remove duplicate arguments
%
% Revision 1.23  2002/10/24 22:15:13  cooper
% Fixed timesout ~= size(RR,2) bug in plotall().
%
% Revision 1.22  2002/10/24 15:09:18  arno
% topoplot channel
%
% Revision 1.21  2002/10/24 02:13:13  arno
% remove nb_points, no longer used
%
% Revision 1.20  2002/10/24 02:10:15  arno
% returning outputs of size adjusted to pling frequency
%
% Revision 1.19  2002/10/18 21:58:58  arno
% new bootstrap plot with cooper
%
% Revision 1.18  2002/10/18 20:53:46  arno
% checking rcs
%
% Revision 1.17  2002/10/17 01:45:02  arno
% editing thanks to cooper
%
% Revision 1.16  2002/10/16 01:29:49  arno
% display -> ms
%
% Revision 1.15  2002/10/15 23:30:04  arno
% debugging tlimits
%
% Revision 1.14  2002/10/15 23:02:31  arno
% time limits warning
%
% Revision 1.13  2002/10/15 22:59:34  arno
% debugging time
%
% Revision 1.12  2002/10/15 22:59:12  arno
% temporary
%
% Revision 1.11  2002/10/15 21:18:52  arno
% bilateral difference
%
% Revision 1.10  2002/10/15 21:10:32  arno
% title
%
% Revision 1.9  2002/10/15 21:07:36  arno
% bilateral bootstrap for difference
%
% Revision 1.8  2002/10/15 20:53:32  arno
% title diff
%
% Revision 1.7  2002/10/15 19:16:23  arno
% debugging wavelets ...
%
% Revision 1.6  2002/10/15 00:11:14  arno
% title bug
%
% Revision 1.5  2002/10/09 18:32:47  arno
% axcopy problem -> only try to execute it
%
% Revision 1.4  2002/10/09 00:01:48  arno
% debug
%
% Revision 1.3  2002/10/05 02:08:27  arno
% outputs for newcrossf
%
% Revision 1.2  2002/10/02 00:35:47  arno
% update condstat, debug
%
% Revision 1.1  2002/10/01 16:06:44  arno
% Initial revision
%
% Revision 1.49  2002/09/12 03:22:44  scott
% help msg -sm
%
% Revision 1.48  2002/08/14 21:06:33  arno
% hanning debug
%
% Revision 1.47  2002/08/14 21:02:54  arno
% implementing hanning funciton
%
% Revision 1.46  2002/08/12 01:48:01  arno
% color
%
% Revision 1.45  2002/08/11 22:30:19  arno
% color
%
% Revision 1.44  2002/08/11 22:28:36  arno
% updating cycles
%
% Revision 1.43  2002/08/09 22:37:32  arno
% debugging cyclefact
%
% Revision 1.42  2002/08/09 22:29:42  arno
% implementing wavelet factor
%
% Revision 1.41  2002/07/26 00:27:56  arno
% significance for all plots
%
% Revision 1.40  2002/07/25 23:05:15  arno
% implementing condition comparison
%
% Revision 1.39  2002/07/16 23:08:25  arno
% correcting freqs for wavelet output
%
% Revision 1.38  2002/07/16 23:00:03  arno
% testing
%
% Revision 1.37  2002/07/16 04:51:07  arno
% *** empty log message ***
%
% Revision 1.36  2002/07/12 23:11:03  arno
% dftfilt->1
%
% Revision 1.35  2002/07/11 20:56:28  arno
% debugging maxamp
%
% Revision 1.34  2002/07/11 18:22:07  arno
% same
%
% Revision 1.33  2002/07/11 18:20:21  arno
% maxamp debug
%
% Revision 1.32  2002/07/11 18:16:00  arno
% implmenting maxamp
%
% Revision 1.31  2002/07/11 17:01:30  arno
% implementing phase coherence 2, speeding up 'coher' and 'phasecoher'
%
% Revision 1.30  2002/07/10 19:12:56  arno
% removing warning messages
%
% Revision 1.29  2002/07/03 23:45:03  arno
% correcting rboot output
%
% Revision 1.28  2002/07/02 21:51:41  scott
% edited help message -sm
%
% Revision 1.27  2002/06/28 17:57:10  arno
% returning coherence magnitudes
%
% Revision 1.26  2002/06/25 22:23:37  arno
% NEW MODULAR VERSION WITH SUBITC
%
% Revision 1.24  2002/05/23 23:33:35  scott
% remove subtraction of mean coherence -sm
%
% Revision 1.23  2002/04/25 02:54:07  arno
% debugging topovec
%
% Revision 1.22  2002/04/25 02:38:12  arno
% change significance (only one sided
%
% Revision 1.21  2002/04/25 02:18:19  arno
% debugging topovec
%
% Revision 1.20  2002/04/24 22:04:49  arno
% debugging error check
%
% Revision 1.19  2002/04/24 21:59:11  arno
% debugging
%
% Revision 1.18  2002/04/24 21:45:18  scott
% topovec bug -sm
%
% Revision 1.17  2002/04/24 21:43:00  scott
% editing topovec code -sm
%
% Revision 1.16  2002/04/24 21:02:28  scott
% added topoplots of two heads -sm
%
% Revision 1.15  2002/04/24 02:43:18  arno
% debugging amplitude coherence
%
% Revision 1.14  2002/04/20 00:53:14  arno
% restorings some outputs options
%
% Revision 1.13  2002/04/19 23:20:23  arno
% changing trial bootstrap, not optimal, waiting for further inputs
%
% Revision 1.12  2002/04/19 19:46:28  arno
% crossf with new trial coherence bootstrap (minus mean)
%
% Revision 1.11  2002/04/12 18:10:55  scott
% added note
%
% Revision 1.10  2002/04/12 01:30:43  arno
% compatibility for returning frequencies with timef
%
% Revision 1.9  2002/04/12 01:13:40  arno
% debuging no ploting option
%
% Revision 1.8  2002/04/12 01:08:13  arno
% change plotamps to plotamp in help message
%
% Revision 1.7  2002/04/12 00:41:37  arno
% programming baseboot
%
% Revision 1.6  2002/04/11 02:39:34  arno
% updated header message
%
% Revision 1.5  2002/04/10 01:29:45  arno
% adding vert optional input
%
% Revision 1.4  2002/04/09 19:36:38  arno
% corrected bootstrap optional input
%
% Revision 1.3  2002/04/09 18:59:06  arno
% corrected typo in header that made the function to crash
%
% Revision 1.2  2002/04/07 02:24:36  scott
% worked on hlpe message, changed some defaults -sm
%
% Revision 1.1  2002/04/05 17:36:45  jorn
% Initial revision
%

% 11-20-98 defined g.linewidth constant -sm
% 04-01-99 made number of frequencies consistent -se
% 06-29-99 fixed constant-Q freq indexing  -se 
% 08-13-99 added cohangle plotting -sm
% 08-20-99 made bootstrap more efficient -sm
% 08-24-99 allow nan values introduced by possible eventlock() preproc. -sm
% 03-16-00 added lead/lag interpretation to help msg - sm & eric visser
% 03-16-00 added axcopy() feature -sm & tpj
% 04-20-00 fixed Rangle sign for wavelets, added verts array -sm
% 01-22-01 corrected help msg when nargin<2 -sm & arno delorme
% 01-25-02 reformated help & license, added links -ad 
% 03-09-02 function restructuration -ad
%  add 'key', val arguments (+ external baseboot, baseline, color axis, angleunit...)
%  add detrending (across time and trials) + 'coher' option for amplitude coherence
%  significance only if alpha is given, ploting options in 'plotamp' and 'plotphase'
% 03-16-02 timeout automatically adjusted if too high -ad 
% 04-03-02 added new options for bootstrap -ad 

% There are 3 "objects" Tf, Coher and Boot which are handled
% - by specific functions under Matlab
%    (Tf) function Tf = tfinit(...) - create object Time Frequency (Tf) associated with some data
%    (Tf) function [Tf, itcvals] = tfitc(...) - compute itc for the selected data
%    (Tf) function [Tf, itcvals] = tfitcpost(Tf, trials) - itc normlisation 
%    (Tf) function [Tf, tmpX] = tfcomp(Tf, trials, times) - compute time freq. decomposition
%    (Coher) function Coher = coherinit(...) - initialize coherence object
%    (Coher) function Coher = cohercomp(Coher, tmpX, tmpY, trial, time) - compute coherence
%    (Coher) function Coher = cohercomppost(Coher, trials) - coherence normalization
%    (Boot) function Boot = bootinit(...) - intialize bootstrap object
%    (Boot) function Boot = bootcomp(...) - compute bootstrap
%    (Boot) function [Boot, Rbootout] = bootcomppost(...) - bootstrap normalization
% - by real objects under C++ (see C++ code)

function [R,mbase,timesout,freqs,Rbootout,Rangle, coherresout, alltfX, alltfY] = crossf(X, Y, frame, tlimits, Fs, varwin, varargin)

%varwin,winsize,nwin,oversmp,maxfreq,alpha,verts,caxmax)

% Commandline arg defaults:
DEFAULT_ANGLEUNITS = 'deg';     % angle plotting units - 'ms' or 'deg'
DEFAULT_EPOCH	= 750;			% Frames per epoch
DEFAULT_TIMELIM = [-1000 2000];	% Time range of epochs (ms)
DEFAULT_FS		= 250;			% Sampling frequency (Hz)
DEFAULT_NWIN	= 200;			% Number of windows = horizontal resolution
DEFAULT_VARWIN	= 0;			% Fixed window length or base on cycles.
% =0: fix window length to nwin
% >0: set window length equal varwin cycles
%     bounded above by winsize, also determines
%     the min. freq. to be computed.
DEFAULT_OVERSMP	= 2;			% Number of times to oversample = vertical resolution
DEFAULT_MAXFREQ = 50;			% Maximum frequency to display (Hz)
DEFAULT_TITLE	= 'Event-Related Coherence';			% Figure title
DEFAULT_ALPHA   = NaN;			% Default two-sided significance probability threshold

%disp('WARNING: this function is not part of the EEGLAB toolbox and should not be distributed');
%disp('         you must contact Arnaud Delorme (arno@salk.edu) for terms of use');

if (nargin < 2)
   help newcrossf
   return
end
coherresout = [];

if ~iscell(X)
	if (min(size(X))~=1 | length(X)<2)
		fprintf('crossf(): x must be a row or column vector.\n');
		return
	elseif (min(size(Y))~=1 | length(Y)<2)
		fprintf('crossf(): y must be a row or column vector.\n');
		return
	elseif (length(X) ~= length(Y))
		fprintf('crossf(): x and y must have same length.\n');
		return
	end
end;

if (nargin < 3)
   frame = DEFAULT_EPOCH;
elseif (~isnumeric(frame) | length(frame)~=1 | frame~=round(frame))
   fprintf('crossf(): Value of frames must be an integer.\n');
   return
elseif (frame <= 0)
   fprintf('crossf(): Value of frames must be positive.\n');
   return
elseif ~iscell(X) & (rem(size(X,2),frame) ~= 0) & (rem(size(X,1),frame) ~= 0)
   fprintf('crossf(): Length of data vectors must be divisible by frames.\n');
   return
end

if (nargin < 4)
   tlimits = DEFAULT_TIMELIM;
elseif (~isnumeric(tlimits) | sum(size(tlimits))~=3)
   error('crossf(): Value of tlimits must be a vector containing two numbers.');
elseif (tlimits(1) >= tlimits(2))
   error('crossf(): tlimits interval must be [min,max].');
end

if (nargin < 5)
   Fs = DEFAULT_FS;
elseif (~isnumeric(Fs) | length(Fs)~=1)
   error('crossf(): Value of srate must be a number.');
elseif (Fs <= 0)
   error('crossf(): Value of srate must be positive.');
end

if (nargin < 6)
   varwin = DEFAULT_VARWIN;
elseif (~isnumeric(varwin) | length(varwin)>2)
   error('crossf(): Value of cycles must be a number or a (1,2) vector.');
elseif (varwin < 0)
   error('crossf(): Value of cycles must be either zero or positive.');
end

% consider structure for these arguments
% --------------------------------------
vararginori = varargin;
for index=1:length(varargin)
	if iscell(varargin{index}), varargin{index} = { varargin{index} }; end;
end;
if ~isempty(varargin)
    [tmp indices] = unique(varargin(1:2:end)); % keep the first one
    varargin = varargin(sort(union(indices*2-1, indices*2))); % these 2 line remove duplicate arguments    
    try, g = struct(varargin{:}); 
    catch, error('Argument error in the {''param'', value} sequence'); end; 
else 
	g = [];
end;

try, g.condboot;   catch, g.condboot = 'abs'; end;
try, g.shuffle;    catch, g.shuffle = 0; end;
try, g.title;      catch, g.title = DEFAULT_TITLE; end;
try, g.winsize;    catch, g.winsize = max(pow2(nextpow2(frame)-3),4); end;
try, g.pad;        catch, g.pad = max(pow2(nextpow2(g.winsize)),4); end;
try, g.timesout;   catch, g.timesout = DEFAULT_NWIN; end;
try, g.padratio;   catch, g.padratio = DEFAULT_OVERSMP; end;
try, g.topovec;    catch, g.topovec = []; end;
try, g.elocs;      catch, g.elocs = ''; end;
try, g.alpha;      catch, g.alpha = DEFAULT_ALPHA; end;  
try, g.marktimes;  catch, g.marktimes = []; end; % default no vertical lines
try, g.marktimes = g.vert;       catch, g.vert = []; end; % default no vertical lines
try, g.rboot;      catch, g.rboot = []; end;
try, g.plotamp;    catch, g.plotamp = 'on'; end;
try, g.plotphase;  catch, g.plotphase  = 'on'; end;
try, g.plotbootsub;  catch, g.plotbootsub  = 'on'; end;
try, g.detrend;    catch, g.detrend = 'off'; end;
try, g.rmerp;      catch, g.rmerp = 'off'; end;
try, g.baseline;   catch, g.baseline = NaN; end;
try, g.baseboot;   catch, g.baseboot = 0; end;
try, g.linewidth;  catch, g.linewidth = 2; end;
try, g.maxfreq;    catch, g.maxfreq = DEFAULT_MAXFREQ; end;
try, g.freqs;      catch, g.freqs = [0 g.maxfreq]; end;
try, g.nfreqs;     catch, g.nfreqs = []; end;
try, g.freqscale;  catch, g.freqscale = 'linear'; end;
try, g.naccu;      catch, g.naccu = 200; end;
try, g.angleunit;  catch, g.angleunit = DEFAULT_ANGLEUNITS; end;
try, g.type;       catch, g.type = 'phasecoher'; end; 
try, g.newfig;     catch, g.newfig = 'on'; end;
try, g.boottype;   catch, g.boottype = 'timestrials'; end; 
try, g.subitc;     catch, g.subitc = 'off'; end;
try, g.compute;    catch, g.compute = 'matlab'; end;
try, g.maxamp;     catch, g.maxamp = []; end;
try, g.savecoher;  catch, g.savecoher = 0; end;
try, g.amplag;     catch, g.amplag = 0; end;
try, g.noinput;    catch, g.noinput = 'no'; end;
try, g.lowmem;     catch, g.lowmem = 'off'; end;

if isfield(g, 'detret'), g.detrend = g.detret; end;
if isfield(g, 'detrep'), g.rmerp   = g.detrep; end;

allfields = fieldnames(g);
for index = 1:length(allfields)
	switch allfields{index}
	 case { 'shuffle' 'title' 'winsize' 'pad' 'timesout' 'padratio' 'maxfreq' 'topovec' 'elocs' 'alpha' ...
		  'marktimes' 'vert' 'rboot' 'plotamp' 'plotphase' 'plotbootsub' 'detrep' 'rmerp' 'detret' 'detrend' ...
		  'baseline' 'baseboot' 'linewidth' 'naccu' 'angleunit' 'type' 'boottype' 'subitc' 'lowmem' ...
		  'compute' 'maxamp' 'savecoher' 'noinput' 'condboot' 'newfig' 'freqs' 'nfreqs' 'freqscale' 'amplag' };
	  case {'plotersp' 'plotitc' }, disp(['crossf warning: timef option ''' allfields{index} ''' ignored']);
	 otherwise disp(['crossf error: unrecognized option ''' allfields{index} '''']); beep; return;
	end;
end;

g.tlimits = tlimits;
g.frame   = frame;
if ~iscell(X) g.trials = prod(size(X))/g.frame;
else          g.trials = prod(size(X{1}))/g.frame;
end;
g.srate   = Fs;
g.cycles  = varwin;
g.type       = lower(g.type);
g.boottype   = lower(g.boottype);
g.rmerp     = lower(g.rmerp);
g.detrend     = lower(g.detrend);
g.plotphase  = lower(g.plotphase);
g.plotbootsub = lower(g.plotbootsub);
g.subitc     = lower(g.subitc);
g.plotamp    = lower(g.plotamp);
g.compute    = lower(g.compute);
g.AXES_FONT  = 10;
g.TITLE_FONT = 14;

% change type if necessary
if g.trials == 1 & ~strcmpi(g.type, 'crossspec')
    disp('Continuous data: switching to crossspectrum');
    g.type = 'crossspec';
end;

% reshape 3D inputs
% -----------------
if ndims(X) == 3
    X = reshape(X, size(X,1), size(X,2)*size(X,3));
    Y = reshape(Y, size(Y,1), size(Y,2)*size(Y,3));
end;

% testing arguments consistency
% -----------------------------
if strcmpi(g.title, DEFAULT_TITLE)
    switch g.type
     case 'coher',       g.title	= 'Event-Related Coherence';			% Figure title
     case 'phasecoher',  g.title	= 'Event-Related Phase Coherence';		
     case 'phasecoher2', g.title	= 'Event-Related Phase Coherence 2';			
     case 'amp'  ,       g.title	= 'Event-Related Amplitude Correlation';		
     case 'crossspec',   g.title	= 'Event-Related Amplitude Correlation';		
    end;
end;

if ~ischar(g.title) & ~iscell(g.title) 
   error('Title must be a string or a cell array.');
end

if isempty(g.topovec)
   g.topovec = [];
elseif min(size(g.topovec))==1
   g.topovec = g.topovec(:);
   if size(g.topovec,1)~=2
      error('topovec must be a row or column vector.');
   end
end;

if isempty(g.elocs)
   g.elocs = '';
elseif (~ischar(g.elocs)) & ~isstruct(g.elocs)
   error('Channel location file must be a valid text file.');
end

if (~isnumeric(g.alpha) | length(g.alpha)~=1)
   error('timef(): Value of g.alpha must be a number.\n');
elseif (round(g.naccu*g.alpha) < 2)
   fprintf('Value of g.alpha is out of the normal range [%g,0.5]\n',2/g.naccu);
   g.naccu = round(2/g.alpha);
   fprintf('  Increasing the number of bootstrap iterations to %d\n',g.naccu);
end
if g.alpha>0.5 | g.alpha<=0
   error('Value of g.alpha is out of the allowed range (0.00,0.5).');
end
switch lower(g.newfig)
    case { 'on', 'off' }, ;
    otherwise error('newfig must be either on or off');
end;
switch g.angleunit
case { 'ms', 'deg' },;
otherwise error('Angleunit must be either ''deg'' or ''ms''');
end;    
switch g.type
case { 'coher', 'phasecoher' 'phasecoher2' 'amp' 'crossspec' },;
otherwise error('Type must be either ''coher'', ''phasecoher'', ''crossspec'', or ''amp''');
end;    
switch g.boottype
case { 'times' 'timestrials' 'timestrials2' 'trials'},;
otherwise error('Boot type must be either ''times'', ''trials'' or ''timestrials''');
end;    
if ~isnumeric(g.shuffle) & ~iscell(g.shuffle)
   error('Shuffle argument type must be numeric');
end;
switch g.compute
case { 'matlab', 'c' },;
otherwise error('compute must be either ''matlab'' or ''c''');
end;
if ~strcmpi(g.condboot, 'abs') & ~strcmpi(g.condboot, 'angle') ...
		& ~strcmpi(g.condboot, 'complex')
	error('Condboot must be either ''abs'', ''angle'' or ''complex''.');
end;
if g.tlimits(2)-g.tlimits(1) < 30
    disp('Crossf WARNING: time range is very small (<30 ms). Times limits are in millisenconds not seconds.'); 
end;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% compute frequency by frequency if low memory
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if strcmpi(g.lowmem, 'on') & ~iscell(X) & length(X) ~= g.frame & (isempty(g.nfreqs) | g.nfreqs ~= 1)
    
    % compute for first 2 trials to get freqsout
    XX = reshape(X, 1, frame, length(X)/g.frame);    
    YY = reshape(Y, 1, frame, length(Y)/g.frame);    
    [coh,mcoh,timesout,freqs] = newcrossf(XX(1,:,1), YY(1,:,1), frame, tlimits, Fs, varwin, 'plotamp', 'off', 'plotphase', 'off',varargin{:});
    
    % scan all frequencies
    for index = 1:length(freqs)
        if nargout < 6
            [R(index,:),mbase(index),timesout,tmpfreqs(index),Rbootout(index,:),Rangle(index,:)] = ...
                newcrossf(X, Y, frame, tlimits, Fs, varwin, 'freqs', [freqs(index) freqs(index)], 'nfreqs', 1, ...
                          'plotamp', 'off', 'plotphase', 'off',varargin{:}, 'lowmem', 'off', 'timesout', timesout);
        elseif nargout == 7 % requires RAM
            [R(index,:),mbase(index),timesout,tmpfreqs(index),Rbootout(index,:),Rangle(index,:), ...
             coherresout(index,:,:)] = ...
                newcrossf(X, Y, frame, tlimits, Fs, varwin, 'freqs', [freqs(index) freqs(index)], 'nfreqs', 1, ...
                          'plotamp', 'off', 'plotphase', 'off',varargin{:}, 'lowmem', 'off', 'timesout', timesout);
        else
            [R(index,:),mbase(index),timesout,tmpfreqs(index),Rbootout(index,:),Rangle(index,:), ...
             coherresout(index,:,:),alltfX(index,:,:),alltfY(index,:,:)] = ...
                newcrossf(X, Y, frame, tlimits, Fs, varwin, 'freqs', [freqs(index) freqs(index)], 'nfreqs', 1, ...
                          'plotamp', 'off', 'plotphase', 'off',varargin{:}, 'lowmem', 'off', 'timesout', timesout);
        end;
    end;
    
    % plot and return
    plotall(R.*exp(j*Rangle), Rbootout, timesout, freqs, mbase, g);
    return;
end;    


%%%%%%%%%%%%%%%%%%%%%%%%%%%
% compare 2 conditions part
%%%%%%%%%%%%%%%%%%%%%%%%%%%
if iscell(X)
	if length(X) ~= 2 | length(Y) ~= 2
		error('crossf: to compare conditions, X and Y input must be 2-elements cell arrays');
	end;
	if ~strcmp(g.boottype, 'times')
		disp('crossf warning: significance bootstrap type is only use for subcondition plots');
	end;
    % deal with titles
    % ----------------
	for index = length(vararginori)-1:-2:1
		if index<=length(vararginori) % needed: if elemenets are deleted
			if strcmp(vararginori{index}, 'title') , vararginori(index:index+1) = []; end;
			if strcmp(vararginori{index}, 'subitc'), vararginori(index:index+1) = []; end;
			if strcmp(vararginori{index}, 'shuffle'), vararginori(index:index+1) = []; end;
		end;
	end;
    if ~iscell(g.subitc)
        g.subitc = { g.subitc g.subitc };
    end;
    if ~iscell(g.shuffle)
        g.shuffle = { g.shuffle g.shuffle };
    end;
	if iscell(g.title) 
		if length(g.title) <= 2,
			g.title{3} = 'Condition 1 - condition 2';
		end;
	else
		g.title = { 'Condition 1', 'Condition 2', 'Condition 1 - condition 2' };
	end;
	
	fprintf('Running crossf on condition 1 *********************\n');
	fprintf('Note: if an out-of-memory error occurs, try reducing the\n');
	fprintf('      number of time points or number of frequencies\n');
	fprintf('      (the ''coher'' options takes 3 times more memory than other options)\n');
    
	if strcmpi(g.plotamp, 'on') | strcmpi(g.plotphase, 'on')
        if strcmpi(g.newfig, 'on'), figure; end; 
        subplot(1,3,1); 
	end;

    if ~strcmp(g.type, 'coher') & nargout < 9
		[R1,mbase,timesout,freqs,Rbootout1,Rangle1, savecoher1] = newcrossf(X{1}, Y{1}, ...
				frame, tlimits, Fs, varwin, 'savecoher', 1, 'title', g.title{1}, ...
                          'shuffle', g.shuffle{1}, 'subitc', g.subitc{1}, vararginori{:});
	else
		[R1,mbase,timesout,freqs,Rbootout1,Rangle1, savecoher1, Tfx1, Tfy1] = newcrossf(X{1}, Y{1}, ...
				frame, tlimits, Fs, varwin, 'savecoher', 1, 'title', g.title{1}, ...
                          'shuffle', g.shuffle{1}, 'subitc', g.subitc{1},  vararginori{:});
	end;
	R1 = R1.*exp(j*Rangle1/180*pi);
	
	fprintf('\nRunning crossf on condition 2 *********************\n');
	if strcmpi(g.plotamp, 'on') | strcmpi(g.plotphase, 'on')
        subplot(1,3,2);
	end;
    if ~strcmp(g.type, 'coher') & nargout < 9
		[R2,mbase,timesout,freqs,Rbootout2,Rangle2, savecoher2] = newcrossf(X{2}, Y{2}, ...
				frame, tlimits, Fs, varwin,'savecoher', 1, 'title', g.title{2}, ...
                            'shuffle', g.shuffle{2}, 'subitc', g.subitc{2}, vararginori{:});
	else
		[R2,mbase,timesout,freqs,Rbootout2,Rangle2, savecoher2, Tfx2, Tfy2] = newcrossf(X{2}, Y{2}, ...
				frame, tlimits, Fs, varwin,'savecoher', 1, 'title', g.title{2}, ...
                            'shuffle', g.shuffle{2}, 'subitc', g.subitc{2}, vararginori{:} );
	end;
	%figure; imagesc(abs( sum( savecoher1 ./ abs(savecoher1), 3)) - abs( sum( savecoher2 ./ abs(savecoher2), 3)  )); cbar; return;
	%figure; imagesc(abs( R2 ) - abs( R1)  ); cbar; return;
	R2 = R2.*exp(j*Rangle2/180*pi);
    
    if strcmpi(g.plotamp, 'on') | strcmpi(g.plotphase, 'on')
        subplot(1,3,3);
	end;
    if isnan(g.alpha)
        switch(g.condboot)
            case 'abs',  Rdiff = abs(R1)-abs(R2);
            case 'angle',  Rdiff = angle(R1)-angle(R2);
            case 'complex',  Rdiff = R1-R2;
        end;
        g.title = g.title{3};
        if strcmpi(g.plotamp, 'on') | strcmpi(g.plotphase, 'on')
            plotall(Rdiff, [], timesout, freqs, mbase, g);
        end;
        Rbootout = [];
	else 
		% preprocess data and run compstat
		% --------------------------------
		switch g.type
		 case 'coher', % take the square of alltfx and alltfy first to speed up
		  Tfx1 = Tfx1.*conj(Tfx1); Tfx2 = Tfx2.*conj(Tfx2);
		  Tfy1 = Tfy1.*conj(Tfy1); Tfy2 = Tfy2.*conj(Tfy2);
		  formula = 'sum(arg1(:,:,X),3) ./ sqrt(sum(arg2(:,:,X),3)) ./ sqrt(sum(arg3(:,:,X),3))';
          if strcmpi(g.lowmem, 'on')
              for ind = 1:2:size(savecoher1,1)
                  if ind == size(savecoher1,1), indarr = ind; else indarr = [ind:ind+1]; end;
                  [Rdiff(indarr,:,:) coherimages(indarr,:,:) coher1(indarr,:,:) coher2(indarr,:,:)] = condstat(formula, g.naccu, g.alpha, ...
                      'both', g.condboot, { savecoher1(indarr,:,:) savecoher2(indarr,:,:) }, ...
                     { Tfx1(indarr,:,:) Tfx2(indarr,:,:) }, { Tfy1(indarr,:,:) Tfy2(indarr,:,:) });
              end;     
          else
              [Rdiff coherimages coher1 coher2] = condstat(formula, g.naccu, g.alpha, ...
                 'both', g.condboot, { savecoher1 savecoher2 }, { Tfx1 Tfx2 }, { Tfy1 Tfy2 });
          end; 
          
         case 'amp' % amplitude correlation
		  error('Cannot compute difference of amplitude correlation images yet');
         
         case 'crossspec' % amplitude correlation
		  error('Cannot compute difference of cross-spectral decomposition');
          
         case 'phasecoher', % normalize first to speed up
		  savecoher1 = savecoher1 ./ sqrt(savecoher1.*conj(savecoher1));
		  savecoher2 = savecoher2 ./ sqrt(savecoher2.*conj(savecoher2)); % twice faster than abs()
		  formula = 'sum(arg1(:,:,X),3) ./ length(X)';
          if strcmpi(g.lowmem, 'on')
              for ind = 1:2:size(savecoher1,1)
                  if ind == size(savecoher1,1), indarr = ind; else indarr = [ind:ind+1]; end;
                  [Rdiff(indarr,:,:) coherimages(indarr,:,:) coher1(indarr,:,:) coher2(indarr,:,:)] = condstat(formula, g.naccu, g.alpha, ...
                      'both', g.condboot, { savecoher1(indarr,:,:) savecoher2(indarr,:,:) } );
              end;     
          else
              [Rdiff coherimages coher1 coher2] = condstat(formula, g.naccu, g.alpha, 'both', g.condboot, ...
														   { savecoher1 savecoher2 });
          end;
		 case 'phasecoher2',
		  savecoher1 = savecoher1 ./ sqrt(savecoher1.*conj(savecoher1));
		  savecoher2 = savecoher2 ./ sqrt(savecoher2.*conj(savecoher2)); % twice faster than abs()
		  formula = 'sum(arg1(:,:,X),3) ./ sum(sqrt(arg1(:,:,X).*conj(arg1(:,:,X)))),3)'; 
		  % sqrt(a.*conj(a)) is about twice faster than abs()
          if strcmpi(g.lowmem, 'on')
              for ind = 1:2:size(savecoher1,1)
                  if ind == size(savecoher1,1), indarr = ind; else indarr = [ind:ind+1]; end;
                  [Rdiff(indarr,:,:) coherimages(indarr,:,:) coher1(indarr,:,:) coher2(indarr,:,:)] = condstat(formula, g.naccu, g.alpha, ...
                      'both', g.condboot, { savecoher1(indarr,:,:) savecoher2(indarr,:,:) } );
              end;     
          else
              [Rdiff coherimages coher1 coher2] = condstat(formula, g.naccu, g.alpha, 'both', g.condboot, ...
														   { savecoher1 savecoher2 });
          end;
		end;
        
		%Boot = bootinit( [], size(savecoher1,1), g.timesout, g.naccu, 0, g.baseboot, 'noboottype', g.alpha, g.rboot);
		%Boot.Coherboot.R = coherimages;
		%Boot = bootcomppost(Boot, [], [], []);
		g.title = g.title{3};
		g.boottype = 'trials';
        if strcmpi(g.plotamp, 'on') | strcmpi(g.plotphase, 'on')
            plotall(Rdiff, coherimages, timesout, freqs, mbase, g);
        end;
        
        % outputs
        Rbootout = {Rbootout1 Rbootout2 coherimages};
	end;
    if size(Rdiff,3) > 1, Rdiff = reshape(Rdiff, 1, size(Rdiff,3)); end;
    R        = { abs(R1) abs(R2) fastif(isreal(Rdiff), Rdiff, abs(Rdiff)) };
    Rangle   = { angle(R1) angle(R2) angle(Rdiff) };
    coherresout = [];
    if nargout >=9
        alltfX = { Tfx1 Tfx2 };
        alltfY = { Tfy1 Tfy2 };
    end;
	return; % ********************************** END FOR SEVERAL CONDITIONS
end;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% shuffle trials if necessary
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if g.shuffle ~= 0
   fprintf('x and y data trials being shuffled %d times\n',g.shuffle);
   XX = reshape(X, 1, frame, length(X)/g.frame);
   YY = Y;
   X = [];
   Y = [];
   for index = 1:g.shuffle
      XX = shuffle(XX,3);
      X = [X XX(:,:)];
      Y = [Y YY];
   end;
end;

% detrend over epochs (trials) if requested
% -----------------------------------------
switch g.rmerp
case 'on'
   X = reshape(X, g.frame, length(X)/g.frame);
   X = X - mean(X,2)*ones(1, length(X(:))/g.frame);
   Y = reshape(Y, g.frame, length(Y)/g.frame);
   Y = Y - mean(Y,2)*ones(1, length(Y(:))/g.frame);
end;        

%%%%%%%%%%%%%%%%%%%%%%
% display text to user
%%%%%%%%%%%%%%%%%%%%%%
fprintf('\nComputing the Event-Related \n');
switch g.type
    case 'phasecoher',  fprintf('Phase Coherence (ITC) images based on %d trials\n',g.trials);
    case 'phasecoher2', fprintf('Phase Coherence 2 (ITC) images based on %d trials\n',g.trials);
    case 'coher',       fprintf('Linear Coherence (ITC) images based on %d trials\n',g.trials);
    case 'amp',         fprintf('Amplitude correlation images based on %d trials\n',g.trials);
    case 'crossspec',   fprintf('Cross-spectral images based on %d trials\n',g.trials);
end;
if ~isnan(g.alpha)
   fprintf('Bootstrap confidence limits will be computed based on alpha = %g\n', g.alpha);
else
   fprintf('Bootstrap confidence limits will NOT be computed.\n'); 
end
switch g.plotphase
case 'on', fprintf(['Coherence angles will be imaged in ',g.angleunit,'\n']);
end;


%%%%%%%%%%%%%%%%%%%%%%%
% main computation loop
%%%%%%%%%%%%%%%%%%%%%%%
if ~strcmp(lower(g.compute), 'c') % MATLAB PART   
	% -------------------------------------
	% compute time frequency decompositions
	% -------------------------------------
    spectraloptions = { 'ntimesout', g.timesout, 'winsize', g.winsize, 'tlimits', g.tlimits, 'detrend', ...
                g.detrend, 'subitc', g.subitc, 'wavelet', g.cycles, 'padratio', g.padratio, ...
                'freqs' g.freqs 'freqscale' g.freqscale 'nfreqs' g.nfreqs };
    if ~strcmpi(g.type, 'amp') & ~strcmpi(g.type, 'crossspec')
        spectraloptions = { spectraloptions{:} 'itctype' g.type };
    end;

    fprintf('\nProcessing first input\n');
	X = reshape(X, g.frame, g.trials);
	[alltfX freqs timesout] = timefreq(X, g.srate, spectraloptions{:});
    fprintf('\nProcessing second input\n');
	Y = reshape(Y, g.frame, g.trials);
	[alltfY] = timefreq(Y, g.srate, spectraloptions{:});
    
	% ------------------
	% compute coherences
	% ------------------
	tmpprod = alltfX .* conj(alltfY);
	switch g.type
	 case 'crossspec',
	  coherres = alltfX .* conj(alltfY); % no normalization
      
	 case 'coher',
	  coherresout = alltfX .* conj(alltfY);
	  coherres = sum(alltfX .* conj(alltfY), 3) ./ sqrt( sum(abs(alltfX).^2,3) .* sum(abs(alltfY).^2,3) );
     
     case 'amp'
      alltfX = abs(alltfX);
      alltfY = abs(alltfY);
      coherres = ampcorr(alltfX, alltfY, freqs, timesout, g);
      g.alpha = NaN;
      coherresout = [];
      
	 case 'phasecoher2',
	  coherresout = alltfX .* conj(alltfY);
	  coherres = sum(coherresout, 3) ./ sum(abs(coherresout),3);
	 
     case 'phasecoher',
	  coherresout = alltfX .* conj(alltfY);
	  coherres = sum( coherresout ./ abs(coherresout), 3) / g.trials;
	end;
	
	% -----------------
	% compute bootstrap
	% -----------------
	if ~isempty(g.rboot)
		Rbootout = g.rboot;
	else
		formulaout = 'coher';
		switch g.type
		 case 'crossspec',
		  formulainit = [ 'coher  = zeros(' int2str(length(freqs)) ',' int2str(g.naccu) ');' ];
		  formula =     [ 'coher  = coher  + arg1.*conj(arg2);' ];
		  formulapost =   ''; 
		 case 'coher',
		  formulainit = [ 'coher  = zeros(' int2str(length(freqs)) ',' int2str(g.naccu) ');' ...
						  'cumulX = zeros(' int2str(length(freqs)) ',' int2str(g.naccu) ');' ...
						  'cumulY = zeros(' int2str(length(freqs)) ',' int2str(g.naccu) ');' ];
		  formula =     [ 'coher  = coher  + arg1.*conj(arg2);' ...
						  'cumulX = cumulX + arg1.*conj(arg1);' ...
						  'cumulY = cumulY + arg2.*conj(arg2);' ];
		  formulapost =   'coher = coher ./ sqrt(cumulX) ./ sqrt(cumulY);'; 
		 case 'amp',
		  formulainit = [ 'ampX   = zeros(' int2str(length(freqs)) ',' int2str(g.naccu) ');' ...
                          'ampY   = zeros(' int2str(length(freqs)) ',' int2str(g.naccu) ');' ...
						  'cumulX = zeros(' int2str(length(freqs)) ',' int2str(g.naccu) ');' ...
						  'cumulY = zeros(' int2str(length(freqs)) ',' int2str(g.naccu) ');' ];
		  formula =     [ 'ampX   = ampX + arg1.*conj(arg2);' ...
                          'ampY   = ampY + arg1.*conj(arg2);' ...
						  'cumulX = cumulX + arg1.*conj(arg1);' ...
						  'cumulY = cumulY + arg2.*conj(arg2);' ];
		  formulapost =   'coher = coher ./ sqrt(cumulX) ./ sqrt(cumulY);'; 
		 case 'phasecoher2',
		  formulainit = [ 'coher  = zeros(' int2str(length(freqs)) ',' int2str(g.naccu) ');' ...
						  'cumul  = zeros(' int2str(length(freqs)) ',' int2str(g.naccu) ');' ];
		  formula =     [ 'tmpprod = arg1.*conj(arg2); coher  = coher  + tmpprod;' ...
						  'cumul   = cumul + abs(tmpprod);' ];
		  formulapost =   'coher = coher ./ cumul;'; 
		 case 'phasecoher',
		  formulainit = [ 'coher  = zeros(' int2str(length(freqs)) ',' int2str(g.naccu) ');' ];
		  formula     =   'tmpprod = arg1.*conj(arg2); coher = coher + tmpprod ./ abs(tmpprod)';
		  formulapost = [ 'coher = coher /' int2str(g.trials) ];
		end;
		
		if ~isnan(g.alpha)
            % finding baseline for bootstrap
            % ------------------------------
            if size(g.baseboot,2) == 1
                if g.baseboot == 0, baselntmp = [];
                elseif ~isnan(g.baseline(1))
                    baselntmp = baseln; 
                else baselntmp = find(timesout <= 0); % if it is empty use whole epoch
                end;
            else
                baselntmp = [];
                for index = 1:size(g.baseboot,1)
                    tmptime   = find(timesout >= g.baseboot(index,1) & timesout <= g.baseboot(index,2));
                    baselntmp = union(baselntmp, tmptime);
                end;
            end;
            if prod(size(g.baseboot)) > 2
                fprintf('Bootstrap analysis will use data in multiple selected windows.\n');
            elseif size(g.baseboot,2) == 2
                fprintf('Bootstrap analysis will use data in range %3.2g-%3.2g ms.\n', g.baseboot(1),  g.baseboot(2));
            elseif g.baseboot
                fprintf('   %d bootstrap windows in baseline (times<%g).\n', length(baselntmp), g.baseboot)
            end;        

            options = { formula, 'boottype', g.boottype, ...
                        'formulapost', formulapost, 'formulainit', formulainit, ...
                        'formulaout', formulaout, 'bootside', 'upper', ...
                        'naccu', g.naccu, 'alpha', g.alpha, 'basevect', baselntmp };
            Rbootout = bootstat(alltfX, alltfY, options{:});               
            % NOTE: it is not necessary to implement lowmem for this function (automatic)
        else Rbootout = [];
        end;
        % note that the bootstrap thresholding is actually performed in the display subfunction plotall()
	end;
	
end;

%%%%%%%%%%
% baseline
%%%%%%%%%%
if size(g.baseline,2) == 2
    baseln = [];
    for index = 1:size(g.baseline,1)
        tmptime   = find(timesout >= g.baseline(index,1) & timesout <= g.baseline(index,2));
        baseln = union(baseln, tmptime);
    end;
    if length(baseln)==0
        error('No point found in baseline');
    end;
else
    if ~isempty(find(timesout < g.baseline))
        baseln = find(timesout < g.baseline); % subtract means of pre-0 (centered) windows
    else
        baseln = 1:length(timesout); % use all times as baseline
    end
end;
if ~isnan(g.alpha) & length(baseln)==0
    fprintf('timef(): no window centers in baseline (times<%g) - shorten (max) window length.\n', g.baseline)
    return
end
if ~isnan(g.baseline)
    mbase = mean(abs(coherres(:,baseln)'));     % mean baseline coherence magnitude
else
    mbase = [];
end;

% plot everything
% ---------------
plotall( coherres, Rbootout, timesout, freqs, mbase, g);

% proces outputs
% --------------
Rangle = angle(coherres);
R = abs(coherres);

return; 
% ***********************************************************************

% ------------------------------
% amplitude correlation function
% ------------------------------
function [coherres, lagmap] = ampcorr(alltfX, alltfY, freqs, timesout, g)
    
    % initialize variables
    % --------------------
    coherres  = zeros(length(freqs), length(timesout), length(g.amplag));
    alpha = zeros(length(freqs), length(timesout), length(g.amplag));
    countlag = 1;
    for lag = g.amplag
        fprintf('Computing %d point lag amplitude correlation, please wait...\n', lag);
        for i1 = 1:length(freqs)
            for i2 = max(1, 1-lag):min(length(timesout)-lag, length(timesout))
                if ~isnan(g.alpha)
                    [tmp1 tmp2] = corrcoef( squeeze(alltfX(i1,i2,:)), squeeze(alltfY(i1,i2+lag,:)) );
                    coherres(i1,i2,countlag)   = tmp1(1,2);
                    alpha(i1,i2,countlag)      = tmp2(1,2);
                else
                    tmp1 = corrcoef( squeeze(alltfX(i1,i2,:)), squeeze(alltfY(i1,i2+lag,:)) );
                    coherres(i1,i2,countlag)   = tmp1(1,2);
                end;
            end;
        end;
        countlag = countlag + 1;
    end;

    % find max corr if different lags
    % -------------------------------
    if length(g.amplag) > 1
        [coherres lagmap] = max(coherres, [], 3);
        dimsize = length(freqs)*length(timesout);
        alpha = reshape(alpha((lagmap(:)-1)*dimsize+[1:dimsize]'),length(freqs), length(timesout));
        % above is same as (but faster)
        % for i1 = 1:length(freqs)
        %    for i2 = 1:length(timesout)
        %        alphanew(i1, i2) = alpha(i1, i2, lagmap(i1, i2));
        %    end;
        % end;
        lagmap = g.amplag(lagmap); % real lag
        coherres = coherres.*exp(j*lagmap/max(abs(g.amplag))); % encode lag in the phase
    else
        lagmap = [];
    end;
    
    % apply significance mask
    % -----------------------
    if ~isnan(g.alpha)
        tmpind = find(alpha(:) > g.alpha);
        coherres(tmpind) = 0;
    end;

% ------------------
% plotting functions
% ------------------
function plotall(R, Rboot, times, freqs, mbase, g) 

switch lower(g.plotphase)
case 'on',  
   switch lower(g.plotamp), 
   case 'on', ordinate1 = 0.67; ordinate2 = 0.1; height = 0.33; g.plot = 1;
   case 'off', ordinate2 = 0.1; height = 0.9; g.plot = 1;
   end;     
case 'off', ordinate1 = 0.1; height = 0.9; 
   switch lower(g.plotamp), 
   case 'on', ordinate1 = 0.1; height = 0.9;  g.plot = 1;
   case 'off', g.plot = 0;
   end;     
end; 

% compute angles
% --------------
Rangle = angle(R);
if ~isreal(R)
    R = abs(R);
    Rraw =R; % raw coherence values
    setylim = 1;
    if ~isnan(g.baseline)
     	R = R - repmat(mbase',[1 g.timesout]); % remove baseline mean
    end;
else
    Rraw = R;
    setylim = 0;
end;

if g.plot
   fprintf('\nNow plotting...\n');
   set(gcf,'DefaultAxesFontSize',g.AXES_FONT)
   colormap(jet(256));
   
   pos = get(gca,'position'); % plot relative to current axes
   q = [pos(1) pos(2) 0 0];
   s = [pos(3) pos(4) pos(3) pos(4)];
   axis('off')
end;

switch lower(g.plotamp)
case 'on' 
   %
   % Image the coherence [% perturbations] 
   %
   RR = R;
   if ~isnan(g.alpha) % zero out (and 'green out') nonsignif. R values
       switch dims(Rboot)
           case 3, RR  (find(RR > Rboot(:,:,1) & (RR < Rboot(:,:,2)))) = 0;
                   Rraw(find(RR > Rboot(:,:,1) & (RR < Rboot(:,:,2)))) = 0;
           case 2, RR  (find(RR < Rboot)) = 0;
                   Rraw(find(RR < Rboot)) = 0;
           case 1, RR  (find(RR < repmat(Rboot(:),[1 size(RR,2)]))) = 0;
                   Rraw(find(RR < repmat(Rboot(:),[1 size(Rraw,2)]))) = 0;
       end; 
   end
    
   h(6) = axes('Units','Normalized', 'Position',[.1 ordinate1 .8 height].*s+q);
   
   map=hsv(300); % install circular color map - green=0, yellow, orng, red, violet = max
   %                                         cyan, blue, violet = min
   map = flipud([map(251:end,:);map(1:250,:)]);
   map(151,:) = map(151,:)*0.9; % tone down the (0=) green!
   colormap(map);
   
   if ~strcmpi(g.freqscale, 'log')
       try, imagesc(times,freqs,RR,max(max(RR))*[-1 1]); % plot the coherence image
       catch, imagesc(times,freqs,RR,[-1 1]); end;
   else 
       try, imagesclogy(times,freqs,RR,max(max(RR))*[-1 1]); % plot the coherence image
       catch, imagesclogy(times,freqs,RR,[-1 1]); end;
   end;
   
   if ~isempty(g.maxamp)
	   caxis([-g.maxamp g.maxamp]);
   end;
   tmpscale = caxis;
   
   hold on
   plot([0 0],[0 freqs(end)],'--m','LineWidth',g.linewidth)
   for i=1:length(g.marktimes)
      plot([g.marktimes(i) g.marktimes(i)],[0 freqs(end)],'--m','LineWidth',g.linewidth);
   end;
   hold off
   set(h(6),'YTickLabel',[],'YTick',[])
   set(h(6),'XTickLabel',[],'XTick',[])
   
   h(8) = axes('Position',[.95 ordinate1 .05 height].*s+q);
   if setylim 
        cbar(h(8),151:300, [0 tmpscale(2)]); % use only positive colors (gyorv) 
   else cbar(h(8),1:300  , [-tmpscale(2) tmpscale(2)]); % use only positive colors (gyorv) 
   end;
   
   %
   % Plot delta-mean min and max coherence at each time point on bottom of image
   %
   
   h(10) = axes('Units','Normalized','Position',[.1 ordinate1-0.1 .8 .1].*s+q); % plot marginal means below
   Emax = max(R); % mean coherence at each time point
   Emin = min(R); % mean coherence at each time point
   plot(times,Emin, times, Emax, 'LineWidth',g.linewidth); hold on;
   plot([times(1) times(length(times))],[0 0],'LineWidth',0.7);
   plot([0 0],[-500 500],'--m','LineWidth',g.linewidth);
   for i=1:length(g.marktimes)
       plot([g.marktimes(i) g.marktimes(i)],[-500 500],'--m','LineWidth',g.linewidth);
   end;
   if ~isnan(g.alpha) & dims(Rboot) > 1
      % plot bootstrap significance limits (base mean +/-)
      switch dims(Rboot)
       case 2, plot(times,mean(Rboot(:,:),1),'g' ,'LineWidth',g.linewidth);
               plot(times,mean(Rboot(:,:),1),'k:','LineWidth',g.linewidth);
       case 3, plot(times,mean(Rboot(:,:,1),1),'g' ,'LineWidth',g.linewidth);
               plot(times,mean(Rboot(:,:,1),1),'k:','LineWidth',g.linewidth);
               plot(times,mean(Rboot(:,:,2),1),'g' ,'LineWidth',g.linewidth);
               plot(times,mean(Rboot(:,:,2),1),'k:','LineWidth',g.linewidth);
      end;
      axis([min(times) max(times) 0 max([Emax(:)' Rboot(:)'])*1.2])
   else
      axis([min(times) max(times) 0 max(Emax)*1.2])
   end;
   
   tick = get(h(10),'YTick');
   set(h(10),'YTick',[tick(1) ; tick(length(tick))])
   set(h(10),'YAxisLocation','right')
   xlabel('Time (ms)')
   ylabel('coh.')
   
   %
   % Plot mean baseline coherence at each freq on left side of image
   %   
   
   h(11) = axes('Units','Normalized','Position',[0 ordinate1 .1 height].*s+q); % plot mean spectrum
   E = abs(mbase); % baseline mean coherence at each frequency
   if ~strcmpi(g.freqscale, 'log')
       plot(freqs,E,'b','LineWidth',g.linewidth); % plot mbase
   else
       semilogy(freqs,E,'b','LineWidth',g.linewidth); % plot mbase
       set(h(5),'View',[90 90])
       divs = linspace(log(freqs(1)), log(freqs(end)), 10);
       set(gca, 'xtickmode', 'manual');
       divs = ceil(exp(divs)); divs = unique(divs); % ceil is critical here, round might misalign
                                                    % out-of border label with within border ticks
       set(gca, 'xtick', divs);       
   end;       
   if ~isnan(g.alpha) % plot bootstrap significance limits (base mean +/-)
       hold on
       if ~strcmpi(g.freqscale, 'log')
           switch dims(Rboot)
            case 1, plot(freqs,Rboot(:),'g' ,'LineWidth',g.linewidth);
                    plot(freqs,Rboot(:),'k:','LineWidth',g.linewidth);
            case 2, plot(freqs,mean(Rboot(:,:),2),'g' ,'LineWidth',g.linewidth);
                    plot(freqs,mean(Rboot(:,:),2),'k:','LineWidth',g.linewidth);
            case 3, plot(freqs,mean(Rboot(:,:,1),2),'g' ,'LineWidth',g.linewidth);
                    plot(freqs,mean(Rboot(:,:,1),2),'k:','LineWidth',g.linewidth);
                    plot(freqs,mean(Rboot(:,:,2),2),'g' ,'LineWidth',g.linewidth);
                    plot(freqs,mean(Rboot(:,:,2),2),'k:','LineWidth',g.linewidth);
           end;  
       else
           switch dims(Rboot)
            case 1, semilogy(freqs,Rboot(:),'g' ,'LineWidth',g.linewidth);
                    semilogy(freqs,Rboot(:),'k:','LineWidth',g.linewidth);
            case 2, semilogy(freqs,mean(Rboot(:,:),2),'g' ,'LineWidth',g.linewidth);
                    semilogy(freqs,mean(Rboot(:,:),2),'k:','LineWidth',g.linewidth);
            case 3, semilogy(freqs,mean(Rboot(:,:,1),2),'g' ,'LineWidth',g.linewidth);
                    semilogy(freqs,mean(Rboot(:,:,1),2),'k:','LineWidth',g.linewidth);
                    semilogy(freqs,mean(Rboot(:,:,2),2),'g' ,'LineWidth',g.linewidth);
                    semilogy(freqs,mean(Rboot(:,:,2),2),'k:','LineWidth',g.linewidth);
           end;  
       end;           
       if ~isnan(max(E))
           axis([freqs(1) freqs(end) 0 max([E Rboot(:)'])*1.2]);
       end;
   else             % plot marginal mean coherence only
      if ~isnan(max(E))
          axis([freqs(1) freqs(end) 0 max(E)*1.2]);
      end;
   end
   
   tick = get(h(11),'YTick');
   set(h(11),'YTick',[tick(1) ; tick(length(tick))])
   set(h(11),'View',[90 90])
   xlabel('Freq. (Hz)')
   ylabel('coh.')
end;

switch lower(g.plotphase)
case 'on'
   %
   % Plot coherence phase lags in bottom panel
   %
   h(13) = axes('Units','Normalized','Position',[.1 ordinate2 .8 height].*s+q);
   if setylim
       if strcmpi(g.type, 'amp') % currrently -1 to 1
           maxangle = max(abs(g.amplag)) * mean(times(2:end) - times(1:end-1));
           Rangle   = Rangle * maxangle;
           maxangle = maxangle+5; % so that the min and the max does not mix
       else
           if strcmp(g.angleunit,'ms')  % convert to ms
               Rangle = (Rangle/(2*pi)).*repmat(1000./freqs(:)',1,length(times)); 
               maxangle = max(max(abs(Rangle)));
           else
               Rangle = Rangle*180/pi; % convert to degrees
               maxangle = 180; % use full-cycle plotting 
           end           
       end;
       Rangle(find(Rraw==0)) = 0; % set angle at non-signif coher points to 0
       
       if ~strcmpi(g.freqscale, 'log')
           imagesc(times,freqs,Rangle,[-maxangle maxangle]); % plot the coherence phase angles
       else
           imagesclogy(times,freqs,Rangle,[-maxangle maxangle]); % plot the coherence phase angles
       end;           
       hold on                                             
       plot([0 0],[0 freqs(end)],'--m','LineWidth',g.linewidth); % zero-time line
       for i=1:length(g.marktimes)
           plot([g.marktimes(i) g.marktimes(i)],[0 freqs(end)],'--m','LineWidth',g.linewidth);
       end;
       
       ylabel('Freq. (Hz)')
       xlabel('Time (ms)')
       
       h(14)=axes('Position',[.95 ordinate2 .05 height].*s+q);
       cbar(h(14),0,[-maxangle maxangle]); % two-sided colorbar
   else 
       axis off;
       text(0, 0.5, 'Real values, no angles');
   end;
end

if g.plot
	try, icadefs; set(gcf, 'color', BACKCOLOR); catch, end;
   if (length(g.title) > 0) % plot title
      axes('Position',pos,'Visible','Off');               
      h(13) = text(-.05,1.01,g.title);
      set(h(13),'VerticalAlignment','bottom')
      set(h(13),'HorizontalAlignment','left')
      set(h(13),'FontSize',g.TITLE_FONT)
   end
   %
   %%%%%%%%%%%%%%% plot topoplot() %%%%%%%%%%%%%%%%%%%%%%%
   %
   if (~isempty(g.topovec))
      h(15) = subplot('Position',[-.1 .43 .2 .14].*s+q);
      if size(g.topovec,2) <= 2
         topoplot(g.topovec(1),g.elocs,'electrodes','off', ...
            'style', 'blank', 'emarkersize1chan', 10);
      else
         topoplot(g.topovec(1,:),g.elocs,'electrodes','off');
      end;
      axis('square')
      
      h(16) = subplot('Position',[.9 .43 .2 .14].*s+q);
      if size(g.topovec,2) <= 2
         topoplot(g.topovec(2),g.elocs,'electrodes','off', ...
            'style', 'blank', 'emarkersize1chan', 10);
      else
         topoplot(g.topovec(2,:),g.elocs,'electrodes','off');
      end;
      axis('square')
   end
   
   try, axcopy(gcf); catch, end;
end;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    COHERENCE OBSOLETE   %%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function for coherence initialisation
% -------------------------------------
function Coher = coherinit(nb_points, trials, timesout, type);
Coher.R  = zeros(nb_points,timesout);       % mean coherence
%Coher.RR = repmat(nan,nb_points,timesout); % initialize with nans
Coher.type = type;
Coher.Rn=zeros(trials,timesout);
switch type
 case 'coher',
  Coher.cumulX = zeros(nb_points,timesout);
  Coher.cumulY = zeros(nb_points,timesout);
 case 'phasecoher2',
  Coher.cumul  = zeros(nb_points,timesout);
end;

% function for coherence calculation
% -------------------------------------
%function Coher = cohercomparray(Coher, tmpX, tmpY, trial);
%switch Coher.type
%   case 'coher',
%      Coher.R = Coher.R + tmpX.*conj(tmpY); % complex coher.
%      Coher.cumulXY = Coher.cumulXY + abs(tmpX).*abs(tmpY);
%   case 'phasecoher',
%      Coher.R = Coher.R + tmpX.*conj(tmpY) ./ (abs(tmpX).*abs(tmpY)); % complex coher.
%      Coher.Rn(trial,:) = 1;
%end % ~any(isnan())

function [Coher,tmptrialcoh] = cohercomp(Coher, tmpX, tmpY, trial, time);
tmptrialcoh = tmpX.*conj(tmpY);
switch Coher.type
 case 'coher',
      Coher.R(:,time) = Coher.R(:,time) + tmptrialcoh; % complex coher.
      Coher.cumulX(:,time) = Coher.cumulX(:,time) + abs(tmpX).^2;
      Coher.cumulY(:,time) = Coher.cumulY(:,time) + abs(tmpY).^2;
 case 'phasecoher2',
      Coher.R(:,time) = Coher.R(:,time) + tmptrialcoh; % complex coher.
      Coher.cumul(:,time) = Coher.cumul(:,time) + abs(tmptrialcoh);
 case 'phasecoher',
      Coher.R(:,time) = Coher.R(:,time) + tmptrialcoh ./ abs(tmptrialcoh); % complex coher.
	  %figure; imagesc(abs(tmpX.*conj(tmpY) ./ (abs(tmpX).*abs(tmpY))));
      Coher.Rn(trial,time) = Coher.Rn(trial,time)+1;
end % ~any(isnan())

% function for post coherence calculation
% ---------------------------------------
function Coher = cohercomppost(Coher, trials);
switch Coher.type
 case 'coher',
   Coher.R = Coher.R ./ sqrt(Coher.cumulX) ./ sqrt(Coher.cumulY);
 case 'phasecoher2',
   Coher.R = Coher.R ./ Coher.cumul;
 case 'phasecoher',
   Coher.Rn = sum(Coher.Rn, 1);
   Coher.R  = Coher.R ./ (ones(size(Coher.R,1),1)*Coher.Rn); % coherence magnitude
end;

% function for 2 conditions coherence calculation
% -----------------------------------------------
function [coherimage, coherimage1, coherimage2] = coher2conddiff( allsavedcoher, alltrials, cond1trials, type, tfx, tfy);
	t1s = alltrials(1:cond1trials);
	t2s = alltrials(cond1trials+1:end);
	switch type
	 case 'coher',
	  coherimage1 = sum(allsavedcoher(:,:,t1s),3) ./ sqrt(sum(tfx(:,:,t1s))) ./ sqrt(sum(tfy(:,:,t1s)));
	  coherimage2 = sum(allsavedcoher(:,:,t2s),3) ./ sqrt(sum(tfx(:,:,t2s))) ./ sqrt(sum(tfy(:,:,t1s)));
	 case 'phasecoher2',
	  coherimage1 = sum(allsavedcoher(:,:,t1s),3) ./ sum(abs(allsavedcoher(:,:,t1s)),3);
	  coherimage2 = sum(allsavedcoher(:,:,t2s),3) ./ sum(abs(allsavedcoher(:,:,t2s)),3);
	 case 'phasecoher',
	  coherimage1 = sum(allsavedcoher(:,:,t1s),3) / cond1trials;
	  coherimage2 = sum(allsavedcoher(:,:,t2s),3) / (size(allsavedcoher,3)-cond1trials);
	end;
	coherimage = coherimage2 - coherimage1;

function w = hanning(n)
if ~rem(n,2)
   w = .5*(1 - cos(2*pi*(1:n/2)'/(n+1)));
   w = [w; w(end:-1:1)];
else
   w = .5*(1 - cos(2*pi*(1:(n+1)/2)'/(n+1)));
   w = [w; w(end-1:-1:1)];
end

function res = dims(array)
    res = min(ndims(array), max(size(array,2),size(array,3)));
