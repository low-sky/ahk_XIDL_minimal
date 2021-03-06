pro ahk_profile_v2,scifile,wavefile=wavefile,slitfile=slitfile

;+
; NAME:
;   ahk_profile_v2
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
FOR slitid=11,11 DO BEGIN
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
	skywave1 = wavearray[*,lineybegin+10:lineybegin+15]
	;print, 'sky1', skywave1[2348:2355,*]
	sky2 = thisslit[*,lineyend-15:lineyend-10]
	skywave2 = wavearray[*,lineyend-15:lineyend-10]
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
	;; NOTE: Does not consider possibility of finding cosmic ray instead of thisline line at the moment,
	scipeak = max(sci_profileregion,peaklocation,/NaN)
	peakindex = ARRAY_INDICES(sci_profileregion, peaklocation)
	print, 'peak index at (x,y) = (', peakindex[0], ',', peakindex[1], ')'


	;; Extract profile across row containing peak value
	slitprofile = sci_profileregion[*,peakindex[1]]
	slitsize = size(slitprofile)
  	nsamp = slitsize(1)
	slitindex = FINDGEN(nsamp)
	slitindex = slitindex + 1

	;;MOMENT FIT
	print, 'Do the moment fit!'

	;;Take minimum (non-zero) value in slitprofile to be background and subtract from slitprofile and scipeak.
	bkgd = min(slitprofile[WHERE(slitprofile GT 0)])
	print, 'bkgd', bkgd
	print, 'where bkgd', WHERE(slitprofile EQ bkgd) MOD nsamp
	slitprofile2 = MAKE_ARRAY(nsamp)
	FOR i=0,nsamp-1 DO BEGIN
		IF slitprofile(i) GT 0 THEN slitprofile2(i) = slitprofile(i) - bkgd
	ENDFOR
	scipeak = scipeak - bkgd


	;; Find the centroid = sum x(n)val(n)/sum val(n); only use values greater than 20% of peak
 	sum1 = 0.
	sum2 = 0.
	FOR i=0,nsamp-1 DO BEGIN
		IF slitprofile2(i) GT 0.20*scipeak THEN BEGIN
			sum1 = sum1 + slitprofile2(i)*i
			sum2 = sum2 + slitprofile2(i)
		ENDIF
  	ENDFOR
	xcen = sum1/sum2
	print, slitprofile2(3150), sum1, sum2

	;; Calculate full-wdith at half maximum by literally take full width at half max (using linear interpolation).
	yhalf = 0.5 * scipeak
	x0 = ROUND(xcen)
	if (x0 LT nsamp-1) then begin
  		i2 = (WHERE(slitprofile2[x0:nsamp-1] LT yhalf))[0]
  		xright = INTERPOL(x0+[i2-1,i2], slitprofile2[x0+i2-1:x0+i2], yhalf)
  	endif else xright = 0
  	if (x0 GT 0) then begin
  		i1 = (reverse(where(slitprofile2[0:x0] LT yhalf)))[0]
  		xleft = interpol([i1,i1+1], slitprofile2[i1:i1+1], yhalf)
  	endif else xleft = 0
  	fwhmmeas = 0.
  	if (xleft NE 0 AND xright NE 0) then fwhmmeas = (xright - xleft) $
  	else if (xleft NE 0) then fwhmmeas = 2*(xcen - xleft) $
  	else if (xright NE 0) then fwhmmeas = 2*(xright - xcen)

	;; Put slit profile, FWHM, and centroid in output structure
	;; Do I want to pass this back to long_reduce, or just save a file to the output directory? Need to comb through long_reduce and figure out.
  	slitstructure = {profile: slitprofile2, fwhm: fwhmmeas, centroid: xcen}

	;; Plot results
	;plot, slitstructure.profile, psym=4, symsize=2.0, xrange=[2100,2170]
  	pmom= PLOT(slitprofile2, xrange=[min(WHERE(slitprofile2))-10,max(WHERE(slitprofile2))+10], Title = 'Moment Fit - Slit '+STRTRIM(slitid,2))
  	t1=TEXT(0.6, 0.80, 'Centroid: '+ STRING(xcen),'r')
  	t2=TEXT(0.6, 0.75, 'FWHM: '+ STRING(fwhmmeas),'r')
  	;pmom.Save, STRMID(scifile,0,13)+'-momentprofile-slit'+STRTRIM(slitid,2)+'.pdf', BORDER=10, RESOLUTION=300, /TRANSPARENT

	;;GAUSSIAN FIT
	print, 'Do the Gaussian fit!'

	;;Only want to fit to non-zero values in slitprofile
	slitprofile3 = slitprofile[WHERE(slitprofile)]
	slitindex3 = slitindex[WHERE(slitprofile)]
	print, 'slitprofile3', slitprofile3[0:5]

	;; To fit 1:

	expr = 'P[0] + GAUSS1(X, P[1:3])' ;; expr now contains an IDL expression which takes a constant value "P[0]" and adds a Gaussian "GAUSS1(X, P[1:3])"
	start = [bkgd, xcen, fwhmmeas/2., scipeak*fwhmmeas/2.] ;; Starting guess for constant value, Gaussian mean, sigma, and area under curve
	result = MPFITEXPR(expr, slitindex3, slitprofile3, 0, start, /WEIGHTS)
	print, 'Gaussian result: ', result

	;; Plot results
	p = PLOT(slitindex3, slitprofile3, yrange=[0,max(slitprofile3)+10], Title='Gaussian Fit - Slit '+STRTRIM(slitid,2))
	pgauss = PLOT(slitindex3, result(0)+gauss1(slitindex3, result(1:3)), 'r', thick=5, /OVERPLOT)
	t1=TEXT(0.6, 0.80, 'Mean: '+ STRING(result(1)),'r')
  	t2=TEXT(0.6, 0.75, 'Sigma: '+ STRING(result(2)),'r')
  	;pgauss.Save, STRMID(scifile,0,13)+'-Gaussianprofile-slit'+STRTRIM(slitid,2)+'.pdf', BORDER=10, RESOLUTION=300, /TRANSPARENT

	;; MPFITPEAK GAUSSIAN FIT
	print, 'Do the mpfitpeak Gaussian fit!'

	yfit = mpfitpeak(slitindex3, slitprofile3, A, /NAN)

	print, A

	;; Plot results
	p = PLOT(slitindex3, slitprofile3, yrange=[0,max(slitprofile3)+10], Title='MPFITPEAK Gaussian Fit - Slit '+STRTRIM(slitid,2))
	pgauss = PLOT(slitindex3, yfit, 'r', thick=5, /OVERPLOT)
	t1=TEXT(0.6, 0.80, 'Mean: '+ STRING(A(1)),'r')
  	t2=TEXT(0.6, 0.75, 'Sigma: '+ STRING(A(2)),'r')
  	;pgauss.Save, STRMID(scifile,0,13)+'-Gaussianprofile-slit'+STRTRIM(slitid,2)+'.pdf', BORDER=10, RESOLUTION=300, /TRANSPARENT

ENDFOR ;End for loop over all slits

end
