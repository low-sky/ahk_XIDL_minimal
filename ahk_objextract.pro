function ahk_objextract,bluescifile,red9scifile,red4scifile,blueslitfile=blueslitfile,bluewavefile=bluewavefile,red9slitfile=red9slitfile,red9wavefile=red9wavefile,red4slitfile=red4slitfile,red4wavefile=red4wavefile

;+
; NAME:
;   ahk_objextract
;
; PURPOSE:
;   From output of long_reduce, fit Gaussian model across each slit profile then extract objects accordingly.
;   General outline -- All steps within loop over slits:
;	1) Restore saved objstr.FLUXMODEL (1-d array of summed fluxes in our lines of interest)
;	2) Fit FLUXMODEL with sum of Gaussians using ahk_profile.pro. Get out 4096x4096 profile.
;	3) Feed profile into long_extract_optimal
;
; CALLING SEQUENCE:
;	spec=ahk_objextract('lblue_600_4000/Science/sci-lblue2082.fits.gz','slitfile='slits-lblue2039.fits',wavefile='wave-lblue2204.fits')
;
; INPUTS:
;
; OPTIONAL INPUTS:
;                
; OUTPUTS:
;
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
;   2-July-2014 -- Written by Alice Koning
;-

;; Restore saved objstr.FLUXMODEL
RESTORE, repstr(scifile,'fits.gz','sav')
;help, final_struct, /str
;var1 = min(WHERE(final_struct.slitid EQ 6))
;print, '!!!!', final_struct.slitid
;print, '!!!!', var1, final_struct[var1].slitid
;stop

;; Get various required extensions out of science file
ivar = xmrdfits(scifile,1)
skyimage = xmrdfits(scifile,2)
objimage = xmrdfits(scifile,3)
outmask = xmrdfits(scifile,4)
waveimg = xmrdfits(wavefile, silent = (keyword_set(verbose) EQ 0), 0)
sciimg = xmrdfits(scifile)
imgminsky = sciimg - skyimage
;; Size of science image
nx = (size(sciimg))[1]
ny = (size(sciimg))[2]
xarr = findgen(nx)## replicate(1.0, ny)
yarr = findgen(ny)## replicate(1.0, nx)

;; Number of slits in image
slitmask = mrdfits(slitfile)
nslit = max(slitmask,/NaN)

;; Loop over slits. Find best fit Gaussian curve for each, then feed to long_extract_optimal.
FOR ii =1,nslit DO BEGIN
	;;Find first object in final_struct with slitid equal to ii (avoids duplicates for slits with more than one object)
	structid = min(WHERE(final_struct.slitid EQ (ii)))
	
	;;Start next iteration if ii is not a slitid in final_struct
	IF (structid EQ -1) THEN CONTINUE

	slitid = final_struct[structid].SLITID
	print, '***** SLITID: ', slitid, ' *****'
	slitindex = [] ;; Array to hold values of index along slit. May not need in final code.
	yfitnorm = [] ;; Array to hold normalized profile of each slit. May not need in final code.
	yfitparams = [] ;; Array to hold parameters that describe yfitnorm of each slit. May not need in final code.

	;; Get object profile along slit
	yfitnotnorm = ahk_profile(*final_struct[structid].FLUXMODEL,slitindex,yfitnorm,yfitparams,slitid=slitid)
	slitprofile = ahk_profile2imarray(slitindex,yfitnorm,slitid=slitid,slitfile=slitfile)

	;; Save normalized profile and slit position to file (to be used for calculating average normalized profile across all 3 gratings)
	WRITE_CSV, 'yfitnorm_slitid'+StrTrim(slitid,2)+'.csv', slitindex, yfitnorm
			

	;; Number of objects in slit. If more than one, must get 1D spectrum for each.
	ymask = (slitprofile GT 0.01) ;; Assumes yfit is normalized *correctly*
	label = label_region(ymask)
	nobj = max(label)
	print, 'Number of objects in slit: ', nobj

	IF nobj EQ 0 THEN BEGIN
		print, 'No profile to return!!'
	ENDIF ELSE BEGIN	
		FOR objid=1,nobj DO BEGIN
			trace=MAKE_ARRAY(ny)
			objlength=MAKE_ARRAY(ny)
			;; Need to loop over rows to find trace (xcen) and average number of included pixels on either side to be box_rad
			FOR row=1,ny-2 DO BEGIN ;; First and last rows of label are all zeros, so skip here
				objindx = []
				objindx = WHERE(label[*,row] EQ objid)
				;print, 'ROW', row, 'OBJINDX', objindx
				trace[row] = MEDIAN(objindx)
				objlength[row] = N_ELEMENTS(objindx)/2.
			
			ENDFOR

			box_rad = MEAN(objlength)

			objmask = MAKE_ARRAY(nx,ny)
			FOR row=1,ny-2 DO BEGIN
				objmask[*,row] = ((xarr[row,*] GT (trace[row] - 1.5*box_rad)) AND (xarr[row,*] LE (trace[row] + 1.5*box_rad)))
			ENDFOR
			;stop
			spec = long_extract_optimal(waveimg, imgminsky, ivar, slitprofile, outmask*objmask, skyimage, trace, BOX_RAD=box_rad)
			;fluxerr = 1.0D/SQRT(spec.NIVAR_OPT)
			;stop	
			;; Save wavelength and flux information to file
			;; WRITE_CSV, 'slit'+STRTRIM(slitid,2)+'_obj'+STRTRIM(objid,2)+'_optfit.csv', spec.wave_opt, spec.flux_opt,fluxerr
			;; WRITE_CSV, 'slit'+STRTRIM(slitid,2)+'_obj'+STRTRIM(objid,2)+'_boxfit.csv', spec.wave_box, spec.flux_box,fluxerr

			;; Output all images etc as they were, but now last science extension contains spec
			rdfits_struct,scifile,scistr ;; read original scifile into structure
			imgname = STRMID(scifile, 15, 8, /REVERSE_OFFSET)
			fileout = imgname+'_slit'+STRTRIM(slitid,2)+'_obj'+STRTRIM(objid,2)+'.fits'
			mwrfits,scistr.im0,fileout,scistr.hdr0,/create
			mwrfits,scistr.im1,fileout,scistr.hdr1 
			mwrfits,scistr.im2,fileout,scistr.hdr2 
			mwrfits,scistr.im3,fileout,scistr.hdr3 
			mwrfits,scistr.im4,fileout,scistr.hdr4 
			mwrfits,spec,fileout,hdr_struct
		
			;; Plot flux vs wavelength
			;p = PLOT(spec.wave_opt, spec.flux_opt, yrange=[0,2000])

		ENDFOR ;; end loop over objects

	ENDELSE

ENDFOR ;; end loop over slits

return, spec

end


