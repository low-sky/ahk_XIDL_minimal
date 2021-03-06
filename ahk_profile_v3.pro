pro ahk_profile_v3,scifile,wavefile=wavefile,slitfile=slitfile

;+
; NAME:
;   ahk_profile_v3
;
; PURPOSE:
;   Loop over slits and determine spatial profile of each based on a single line (e.g. Halpha 6562.82 in red, Hbeta 4861.33 or OIII 5006.84 in blue).
;
; CALLING SEQUENCE:
;
; INPUTS:
;    scifile  -- science image (multi extension FITS, processed 2D image of data is 0th extension)
;    wavefile -- FITS image of wavelength solution (wave-xxx.fits output by long_reduce)
;    slitfile -- binary FITS table (or FITS image??) containing the parameters which describe the slit edges (slits-xxx.fits output by long_reduce)
;
; OPTIONAL INPUTS:
;                
; OUTPUTS:
;  Returns the line profile in counts along the slit. 
;
; OPTIONAL OUTPUTS:
;   
; COMMENTS:
;
; EXAMPLES:
;
; BUGS:
;
; PROCEDURES CALLED:
;
; REVISION HISTORY:
;   12-June-2014 -- Written by Alice Koning
;-

;; Check for each input file
if  KEYWORD_SET(scifile) then print,'Science image file: ' + scifile $
else begin
	print, 'No science file found. Leaving ahk_profile.'
	return
endelse

if  KEYWORD_SET(wavefile) then print,'Wavelength solution file: ' + wavefile $
else begin
	print, 'No wavelength solution file found. Leaving ahk_profile.'
	return
endelse

if  KEYWORD_SET(slitfile) then print,'Slit edges file: ' + slitfile $
else begin
	print, 'No slit file found. Leaving ahk_profile.'
	return
endelse

;; Determine if science frame is on red or blue side of LRIS (will be used later to choose which line to search for in slit)
if STRMATCH(scifile, '*lblue*') then colour = 0 $
else colour = 1

;; Extract i-th slit from scifile using slit edges given by slitfile
sciarray = mrdfits(scifile)
wavearray = mrdfits(wavefile)
slitarray = mrdfits(slitfile)

;; Find how many slits are in science image
nslit = max(slitarray,/NaN)
print,'Number of slits detected: ' + STRTRIM(nslit, 2)

;; Start loop over slits to find profile in each
;FOR slitid=1,nslit DO BEGIN
FOR slitid=9,9 DO BEGIN
	thismask = (slitarray EQ slitid) ;; Array of same size as slitarray, contains 1's (when in slit) and 0's (anywhere else)

	;; Get mask parameters
	masksize = size(thismask)
	ncolmask = masksize(1)
	maskbeginindex = min(WHERE(thismask))
	maskendindex = max(WHERE(thismask))
	maskxbegin = maskbeginindex MOD ncolmask
	maskxend = maskendindex MOD ncolmask

	;; Trim pixels on either side (along slit direction, not dispersion direction)
	thismask[0:maskxbegin+5,*] = 0.
	thismask[maskxend-8:-5,*] = 0.
	

        thisslit = thismask*sciarray ;; Do not change sci image values in slit, make all others zero
	;print, thisslit[2000:2300,1638] ;;Test values good for slit 9
	wave_thisslit = thismask*wavearray
	;print, wave_thisslit[2094,1600:1650] ;;Test values good for slit 9

	;; Find array indices which correspond to wavelengths near thisline.
	if colour EQ 0 then begin
		print, 'BLUE!!'
		thisline = ((wave_thisslit LT 5008) and (wave_thisslit GT 5005)) ;; Array of 1's (when near emission line wavelength) and 0's (anywhere else)
		sci_profileregion = thisline*thisslit
	endif else begin
		print, 'RED!!'
		thisline = ((wave_slitlocation LT 6568) and (wave_slitlocation GT 6558))
		sci_profileregion = thisline*thisslit
	endelse

	;; Look +/- 15 pixels away from sci_profileregion (along wavelength direction) and build up a sky brightness profile.
	;; Interpolate across the line, then subtract.

	;; Start by getting thisline parameters
	linesize = size(thisline)
	ncolline = linesize(1)
	nrowline = linesize(2)
	linebeginindex = min(WHERE(thisline))
	lineendindex = max(WHERE(thisline))
	linexbegin = linebeginindex MOD ncolline
	linexend = lineendindex MOD ncolline

	;; Next find the sky flux and wavelengths on either side of the line profile region
	lineybegin = linebeginindex / ncolline
	lineyend = lineendindex / ncolline
	;print, 'liney begin and end', lineybegin, lineyend
	sky1 = thisslit[*,lineybegin+10:lineybegin+15]
	skywave1 = wavearray[*,lineybegin+25:lineybegin+30]
	;print, 'sky1', skywave1[2348:2355,*]
	sky2 = thisslit[*,lineyend-15:lineyend-10]
	skywave2 = wavearray[*,lineyend-30:lineyend-25]
	;print, 'sky2', skywave2[2348:2355,*]
	sky = [[sky2],[sky1]]
	skywave = [[skywave2],[skywave1]]
	;print, 'sky', sky[2348:2355,*]
	;print, 'size of sky', size(sky)

	;; Define array with wavelengths in sci_profileregion, then do the linear interpretation to find sky values at these wavelengths
	wave_profileregion = thisline * wave_thisslit
	sky_profileregion = MAKE_ARRAY(ncolline,nrowline)
	FOR i = 0,ncolline-1 DO sky_profileregion(i,*)=INTERPOL(sky(i,*),skywave(i,*),wave_profileregion(i,*), /NAN)

	;; Replace -NaN values output by INTERPOL with zeros.
	;; Either of the following two lines will accomplish this. Can choose best option once rest of code is finalized.
	sky_profileregion = sky_profileregion*thisline
	;FOREACH element, sky_profileregion DO sky_profileregion[WHERE(element NE element)] = 0

	;; Check output
	;print, size(sky_profileregion)
	;print, 'sky_profileregion', sky_profileregion[2348:2355,1756:1760]

	;; Subtract sky from science when sky GT 0 (avoids NaN's)
	;print, 'sci_profileregion before', sci_profileregion[2348:2355,1756:1760]
	goodindex = WHERE(sky_profileregion GT 0)
	sci_profileregion[goodindex] = sci_profileregion[goodindex] - sky_profileregion[goodindex]
	;print, 'sci_profileregion3 after', sci_profileregion[2348:2355,1759]	
	;plot, sci_profileregion[2340:2460,1759]

	;; Find coordinate in sci_profileregion (ie near thisline) which corresponds to the maximum pixel value after sky subtraction.
	;; Should find thisline, regardless of whether or not the wavelength calibration is slightly off or not.
	;; NOTE: Does not consider possibility of finding cosmic ray instead of thisline line at the moment.
	scipeak = max(sci_profileregion,peaklocation,/NaN)
	peakindex = ARRAY_INDICES(sci_profileregion, peaklocation)
	print, 'peak index at (x,y) = (', peakindex[0], ',', peakindex[1], ')'


	;; Extract profile across row containing peak value
	slitprofile = sci_profileregion[*,peakindex[1]]
	slitsize = size(slitprofile)
  	nsamp = slitsize(1)
	slitindex = FINDGEN(nsamp)
	slitindex = slitindex + 1

	;; Now we would like to find how many local maxima are in the line profile and how spread out they are.
	;; Need to do amplitude cut so we aren't finding a bunch of local maxima in the noise.
	;; If a fit is getting nonsense/nonideal results, checking params in this block of code is the first thing to do!
	bkgd = min(slitprofile[WHERE(slitprofile GT 0)])
	print, 'bkgd', bkgd
	print, 'where bkgd', WHERE(slitprofile EQ bkgd) MOD nsamp
	localmaxindex = find_nminima(-slitprofile, nfind=10, width=10, minsep=20)
	localmaxindexCut = localmaxindex[WHERE(slitprofile[localmaxindex] GT (0.13*(scipeak-bkgd)))]
	print, 'local max at', localmaxindex
	print, 'After cut, local max at', localmaxindexCut
	print, 'local max values', slitprofile[localmaxindexCut]

	;;Only want to fit to non-zero values in slitprofile
	slitprofile2 = slitprofile[WHERE(slitprofile)]
	slitindex2 = slitindex[WHERE(slitprofile)]
	print, 'slitprofile2', slitprofile2[0:5]

	;;Minimum separation between peaks to determine if "well separated" or not
	minpeaksep = 30

	IF n_elements(localmaxindexCut) EQ 0 THEN BEGIN
		print, 'Error: no peaks were found in sky subtracted line profile.'
		RETURN

	ENDIF ELSE IF n_elements(localmaxindexCut) EQ 1 THEN BEGIN
		;; e.g. slit 7
		print, 'One local maximum found in sky subtracted line profile. Doing Gaussian fit with mpfitpeak.'

		yfit = mpfitpeak(slitindex2, slitprofile2, result, /NAN)
		print, result

		;; Plot results
		p = PLOT(slitindex2, slitprofile2, yrange=[0,max(slitprofile2)+10], Title='MPFITPEAK Gaussian Fit - Slit '+STRTRIM(slitid,2))
		pgauss = PLOT(slitindex2, yfit, 'r', thick=5, /OVERPLOT)
		t1=TEXT(0.6, 0.80, 'Mean: '+ STRING(result(1)),'r')
  		t2=TEXT(0.6, 0.75, 'Sigma: '+ STRING(result(2)),'r')
  		;pgauss.Save, STRMID(scifile,0,13)+'-Gaussianprofile-slit'+STRTRIM(slitid,2)+'.pdf', BORDER=10, RESOLUTION=300, /TRANSPARENT

	ENDIF ELSE IF n_elements(localmaxindexCut) EQ 2 THEN BEGIN
		print, 'Two local maxima found in sky subtracted line profile.'

		yfit1 = mpfitpeak(slitindex2, slitprofile2, result1, /NAN)
		print, result1

		slitprofile_rem = slitprofile2 - yfit1
		yfit2 = mpfitpeak(slitindex2, slitprofile_rem, result2, /NAN)
		;testplot = plot(slitindex2, slitprofile_rem)
		;testplot2 = plot(slitindex2, yfit2, /OVERPLOT)
		print, result2

		expr = 'P[0] + GAUSS1(X, P[1:3]) + GAUSS1(X, P[4:6])' ;; Takes a constant value "P[0]" and adds 2 Gaussians
		start = [bkgd, result1(1), result1(2) , result1(0)*result1(2), result2(1), result2(2) , result2(0)*result2(2)]
		result = MPFITEXPR(expr, slitindex2, slitprofile2, 0, start, /WEIGHTS, /QUIET)
		print, 'Gaussian result: ', result
			
	
		p = PLOT(slitindex2, slitprofile2, yrange=[0,max(slitprofile2)+10], Title='Gaussian Fit - Slit '+STRTRIM(slitid,2))
		pgauss = PLOT(slitindex2, result(0)+gauss1(slitindex2, result(1:3)) + gauss1(slitindex2, result(4:6)), 'r', thick=5, /OVERPLOT)
		;t1=TEXT(0.6, 0.80, 'Mean: '+ STRING(result(1)),'r')
  		;t2=TEXT(0.6, 0.75, 'Sigma: '+ STRING(result(2)),'r')
  		;pgauss.Save, STRMID(scifile,0,13)+'-Gaussianprofile-slit'+STRTRIM(slitid,2)+'.pdf', BORDER=10, RESOLUTION=300, /TRANSPARENT

	ENDIF ELSE IF n_elements(localmaxindexCut) EQ 3 THEN BEGIN
		print, 'Three local maxima found in sky subtracted line profile.'

		yfit1 = mpfitpeak(slitindex2, slitprofile2, result1, /NAN)
		print, result1

		slitprofile_rem = slitprofile2 - yfit1
		yfit2 = mpfitpeak(slitindex2, slitprofile_rem, result2, /NAN)
		;testplot1 = plot(slitindex2, slitprofile_rem)
		;testplot2 = plot(slitindex2, yfit2, /OVERPLOT)
		print, result2

		slitprofile_rem2 = slitprofile_rem - yfit2
		yfit3 = mpfitpeak(slitindex2, slitprofile_rem2, result3, /NAN)
		;testplot3 = plot(slitindex2, slitprofile_rem2)
		;testplot4 = plot(slitindex2, yfit3, /OVERPLOT)
		print, result3

		expr = 'P[0] + GAUSS1(X, P[1:3]) + GAUSS1(X, P[4:6]) + GAUSS1(X, P[7:9])' ;; Takes a constant value "P[0]" and adds 2 Gaussians
		start = [bkgd, result1(1), result1(2) , result1(0)*result1(2), result2(1), result2(2) , result2(0)*result2(2), result3(1), result3(2) , $
			result3(0)*result3(2)]
		result = MPFITEXPR(expr, slitindex2, slitprofile2, 0, start, /WEIGHTS, /QUIET)
		print, 'Gaussian result: ', result

		;; Plot results
		p = PLOT(slitindex2, slitprofile2, yrange=[0,max(slitprofile2)+10], Title='Gaussian Fit - Slit '+STRTRIM(slitid,2))
		pgauss = PLOT(slitindex2, result(0)+gauss1(slitindex2, result(1:3)) + gauss1(slitindex2, result(4:6)) $
			+ gauss1(slitindex2, result(7:9)), 'r', thick=5, /OVERPLOT)

	ENDIF ELSE IF n_elements(localmaxindexCut) EQ 4 THEN BEGIN
		print, 'Four local maxima found in sky subtracted line profile.'

		yfit1 = mpfitpeak(slitindex2, slitprofile2, result1, /NAN)
		print, result1

		slitprofile_rem = slitprofile2 - yfit1
		yfit2 = mpfitpeak(slitindex2, slitprofile_rem, result2, /NAN)
		;testplot1 = plot(slitindex2, slitprofile_rem)
		;testplot2 = plot(slitindex2, yfit2, /OVERPLOT)
		print, result2

		slitprofile_rem2 = slitprofile_rem - yfit2
		yfit3 = mpfitpeak(slitindex2, slitprofile_rem2, result3, /NAN)
		;testplot3 = plot(slitindex2, slitprofile_rem2)
		;testplot4 = plot(slitindex2, yfit3, /OVERPLOT)
		print, result3

		slitprofile_rem3 = slitprofile_rem2 - yfit3
		yfit4 = mpfitpeak(slitindex2, slitprofile_rem3, result4, /NAN)
		;testplot5 = plot(slitindex2, slitprofile_rem2)
		;testplot6 = plot(slitindex2, yfit3, /OVERPLOT)
		print, result4

		expr = 'P[0] + GAUSS1(X, P[1:3]) + GAUSS1(X, P[4:6]) + GAUSS1(X, P[7:9]) + GAUSS1(X, P[10:12])' ;; Takes a constant value "P[0]" and adds 4 Gaussians
		start = [bkgd, result1(1), result1(2) , result1(0)*result1(2), result2(1), result2(2) , result2(0)*result2(2), result3(1), result3(2) , $
			result3(0)*result3(2), result4(1), result4(2) , result4(0)*result4(2)]
		result = MPFITEXPR(expr, slitindex2, slitprofile2, 0, start, /WEIGHTS, /QUIET)
		print, 'Gaussian result: ', result

		;; Plot results
		p = PLOT(slitindex2, slitprofile2, yrange=[0,max(slitprofile2)+10], Title='Gaussian Fit - Slit '+STRTRIM(slitid,2))
		pgauss = PLOT(slitindex2, result(0)+gauss1(slitindex2, result(1:3)) + gauss1(slitindex2, result(4:6)) $
			+ gauss1(slitindex2, result(7:9))+ gauss1(slitindex2, result(10:12)), 'r', thick=5, /OVERPLOT)

	ENDIF ELSE IF n_elements(localmaxindexCut) GT 4 THEN BEGIN
		print, 'More than four local maxima found in sky subtracted line profile. Uh oh!'

		result = 100.


	ENDIF

	;; Append final mean, fwhm, area under curve (i.e. mpfitexpr results) to data file
	openw, 1, 'ahk_profile.dat', /append
	printf, 1, slitid, result
	close,1

ENDFOR ;End for loop over all slits

end

;; Trial code for comparing methods when fitting two close together peaks: mpfitpeak vs mpfitexpr. Find no difference in output, but mpfitpeak is much simpler.

			print, 'Local maxima are not well separated. Will fit larger peak with mpfitpeak, subtract, then fit second. Refit both with output params.'

			IF slitprofile[localmaxindexCut[1]] GT slitprofile[localmaxindexCut[0]] THEN BEGIN
				bigpeakindex=localmaxindexCut[1]
				bigpeakvalue=slitprofile[localmaxindexCut[1]]
				smallpeakindex=localmaxindexCut[0]
				smallpeakvalue=slitprofile[localmaxindexCut[0]]
			ENDIF ELSE BEGIN
				bigpeakindex=localmaxindexCut[0]
				bigpeakvalue=slitprofile[localmaxindexCut[0]]
				smallpeakindex=localmaxindexCut[1]
				smallpeakvalue=slitprofile[localmaxindexCut[1]]
			ENDELSE

			fwhmstart = N_ELEMENTS(WHERE(slitprofile))/4.
			expr = 'P[0] + GAUSS1(X, P[1:3])'
			exprFull = 'P[0] + GAUSS1(X, P[1:3]) + GAUSS1(X, P[4:6])'

			start1 = [bkgd, bigpeakindex, fwhmstart/2., bigpeakvalue*fwhmstart/2.]
			result1 = MPFITEXPR(expr, slitindex2, slitprofile2, 0, start1, /WEIGHTS)
			print, 'Gaussian result: ', result1

			slitprofile_rem = slitprofile2 - (result1(0)+gauss1(slitindex2, result1(1:3)))
			start2 = [bkgd, smallpeakindex, fwhmstart/2., smallpeakvalue*fwhmstart/2.]
			result2 = MPFITEXPR(expr, slitindex2, slitprofile_rem, 0, start2, /WEIGHTS)
			print, 'Gaussian result: ', result2

			start = [(result1(0)+result2(0)), result1(1), result1(2), result1(3), result2(1), result2(2), result2(3)]
			result = MPFITEXPR(exprFull, slitindex2, slitprofile2, 0, start, /WEIGHTS)
			print, 'Gaussian result: ', result
