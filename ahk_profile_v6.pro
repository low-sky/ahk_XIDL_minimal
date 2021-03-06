function ahk_profile_v6,slitim ;,yfitfinal

;+
; NAME:
;   ahk_profile_v6
;
; PURPOSE:
;   Fit gaussian(s) + linear baseline across input vector to determine locations of objects (gaussians) and sky (baseline).
;
; CALLING SEQUENCE:
;
; INPUTS:
;    slitim  -- 1-d array of flux across slit in spatial direction.
;
; OPTIONAL INPUTS:
;                
; OUTPUTS:
; Boolean 1-d array of location of sky(1) and object(0)
; 1-d array of y values in final Gaussian + Linear baseline fit (implicit xvalues = indices)
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
;   26-June-2014 -- Written by Alice Koning
;-


;;Fit Gaussian using mpfitpeak and subtract. Repeat until only noise remains. Redo fit using all found mpfitpeak as starting point for mpfitexpr.
params = [] ;; Declare empty array to put params found from mpfitpeak
slitprofile_rem = slitim ;; Copy slitim into variable which will have each new fit subtracted from it
slitindex = findgen(N_ELEMENTS(slitim))
;print, 'slitim: ', slitim
;print, 'index: ', slitindex

REPEAT BEGIN
	mpnterms=5
   	yfit = mpfitpeak(slitindex, slitprofile_rem, fitresult, NTERMS=mpnterms, /NAN, /POSITIVE)
	params = [params,fitresult]
	;testplot1 = plot(slitindex, slitprofile_rem)
	;testplot2 = plot(slitindex, yfit, /OVERPLOT)
	slitprofile_rem=slitprofile_rem-yfit
	;print, fitresult
ENDREP UNTIL fitresult(0)*fitresult(2) LT 50 ;; or use: fitresult(0) LT 6*abs(fitresult(3))

CASE 1 OF
	(N_ELEMENTS(params)/mpnterms EQ 1): BEGIN
		print, 'One local maximum found in sky subtracted line profile.'
		expr = 'P[0] + P[1]*X + GAUSS1(X, P[2:4])'
		start = [params(3),params(4), params(1), params(2) , params(0)*params(2)]
		result = MPFITEXPR(expr, slitindex, slitim, 0, start, /WEIGHTS, /QUIET)
		print, 'Gaussian result: ', result

		yfitfinal = result(0)+result(1)*slitindex+gauss1(slitindex, result(2:4))

		p = PLOT(slitindex, slitim, yrange=[min(slitim)-5,max(slitim)+5])
		pgauss = PLOT(slitindex, yfitfinal, 'r', thick=5, /OVERPLOT)
	END
	(N_ELEMENTS(params)/mpnterms EQ 2): BEGIN
		print, 'Two local maxima found in sky subtracted line profile.'

		expr = 'P[0] + P[1]*X + GAUSS1(X, P[2:4]) + GAUSS1(X, P[5:7])' 
		start = [params(3),params(4), params(1), params(2) , params(0)*params(2), params(6), params(7) , params(5)*params(7)]
		result = MPFITEXPR(expr, slitindex, slitim, 0, start, /WEIGHTS, /QUIET)
		print, 'Gaussian result: ', result

		yfitfinal = result(0)+result(1)*slitindex+gauss1(slitindex, result(2:4)) + gauss1(slitindex, result(5:7))

		p = PLOT(slitindex, slitim, yrange=[min(slitim)-5,max(slitim)+5])
		pgauss = PLOT(slitindex, yfitfinal, 'r', thick=5, /OVERPLOT)

	END
	(N_ELEMENTS(params)/mpnterms EQ 3): BEGIN
		print, 'Three local maxima found in sky subtracted line profile.'

		expr = 'P[0] + P[1]*X + GAUSS1(X, P[2:4]) + GAUSS1(X, P[5:7]) + GAUSS1(X, P[8:10])'
		start = [params(3),params(4), params(1), params(2) , params(0)*params(2), params(6), params(7) , params(5)*params(7), $
			 params(11), params(12) , params(10)*params(12)]
		result = MPFITEXPR(expr, slitindex, slitim, 0, start, /WEIGHTS, /QUIET)
		print, 'Gaussian result: ', result

		yfitfinal = result(0)+result(1)*slitindex+gauss1(slitindex, result(2:4)) + gauss1(slitindex, result(5:7)) $
			+ gauss1(slitindex, result(8:10))

		p = PLOT(slitindex, slitim, yrange=[min(slitim)-5,max(slitim)+5])
		pgauss = PLOT(slitindex, yfitfinal, 'r', thick=5, /OVERPLOT)

	END
	(N_ELEMENTS(params)/mpnterms EQ 4): BEGIN
		print, 'Four local maxima found in sky subtracted line profile.'

		expr = 'P[0] + P[1]*X + GAUSS1(X, P[2:4]) + GAUSS1(X, P[5:7]) + GAUSS1(X, P[8:10]) + GAUSS1(X, P[11:13])'
		start = [params(3),params(4), params(1), params(2) , params(0)*params(2), params(6), params(7) , params(5)*params(7), $
			 params(11), params(12) , params(10)*params(12), params(16), params(17) , params(15)*params(17)]
		result = MPFITEXPR(expr, slitindex, slitim, 0, start, /WEIGHTS, /QUIET)
		print, 'Gaussian result: ', result

		yfitfinal = result(0)+result(1)*slitindex+gauss1(slitindex, result(2:4)) + gauss1(slitindex, result(5:7)) $
			+ gauss1(slitindex, result(8:10)) + gauss1(slitindex, result(11:13))

		p = PLOT(slitindex, slitim, yrange=[min(slitim)-5,max(slitim)+5])
		pgauss = PLOT(slitindex, yfitfinal, 'r', thick=5, /OVERPLOT)

	END
	(N_ELEMENTS(params)/mpnterms EQ 5): BEGIN
		print, 'Five local maxima found in sky subtracted line profile.'

		expr = 'P[0] + P[1]*X + GAUSS1(X, P[2:4]) + GAUSS1(X, P[5:7]) + GAUSS1(X, P[8:10]) + GAUSS1(X, P[11:13]) + GAUSS1(X, P[14:16])'
		start = [params(3),params(4), params(1), params(2) , params(0)*params(2), params(6), params(7) , params(5)*params(7), $
			 params(11), params(12) , params(10)*params(12), params(16), params(17) , params(15)*params(17), $
			params(21), params(22) , params(20)*params(22)]
		result = MPFITEXPR(expr, slitindex, slitim, 0, start, /WEIGHTS, /QUIET)
		print, 'Gaussian result: ', result

		yfitfinal = result(0)+result(1)*slitindex+gauss1(slitindex, result(2:4)) + gauss1(slitindex, result(5:7)) $
			+ gauss1(slitindex, result(8:10)) + gauss1(slitindex, result(11:13)) + gauss1(slitindex, result(14:16))
	
		p = PLOT(slitindex, slitim, yrange=[min(slitim)-5,max(slitim)+5])
		pgauss = PLOT(slitindex, yfitfinal, 'r', thick=5, /OVERPLOT)

	END
	(N_ELEMENTS(params)/mpnterms EQ 6): BEGIN
		print, 'Six local maxima found in sky subtracted line profile.'

		expr = 'P[0] + P[1]*X + GAUSS1(X, P[2:4]) + GAUSS1(X, P[5:7]) + GAUSS1(X, P[8:10]) + GAUSS1(X, P[11:13]) + GAUSS1(X, P[14:16]) + GAUSS1(X, P[17:19])'
		start = [params(3),params(4), params(1), params(2) , params(0)*params(2), params(6), params(7) , params(5)*params(7), $
			 params(11), params(12) , params(10)*params(12), params(16), params(17) , params(15)*params(17), $
			params(21), params(22) , params(20)*params(22), params(26), params(27) , params(25)*params(27)]
		result = MPFITEXPR(expr, slitindex, slitim, 0, start, /WEIGHTS, /QUIET)
		print, 'Gaussian result: ', result

		yfitfinal = result(0)+result(1)*slitindex+gauss1(slitindex, result(2:4)) + gauss1(slitindex, result(5:7)) $
			+ gauss1(slitindex, result(8:10)) + gauss1(slitindex, result(11:13)) + gauss1(slitindex, result(14:16)) $
			+ gauss1(slitindex, result(17:19))

		p = PLOT(slitindex, slitim, yrange=[min(slitim)-5,max(slitim)+5])
		pgauss = PLOT(slitindex, yfitfinal, 'r', thick=5, /OVERPLOT)

	END
ELSE: BEGIN
	print, 'Error identifying peaks.'
	result = 0.00
	yfitfinal = 0.00
	p = PLOT(slitindex, slitim, yrange=[min(slitim)-5,max(slitim)+5])
END
ENDCASE


;; Put sky location into boolean 1-d array
;; sky location defined as when fitted gaussian(s) less than some fraction of peak value. Change this?
skylocpos=WHERE( (yfitfinal LE (1.03*(result(0)+slitindex*result(1)))) AND ((result(0)+slitindex*result(1)) GE 0) )
skylocneg=WHERE( (yfitfinal LE (0.97*(result(0)+slitindex*result(1)))) AND ((result(0)+slitindex*result(1)) LT 0) )
skylocall = [skylocneg,skylocpos]
skyloc = skylocall[SORT(skylocall)]
;print, skyloc

return, skyloc

end
