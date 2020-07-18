
# debian package stuff, maintainers only
DEBRT = $(OPA)/debpackage

DEBSECTION = B
DEBPKG = $(shell echo $(TARGET) | sed "s/_//g;y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/")

ifeq ($(MAKE_T),$(KMOD))
	# kernel module
	DEBSECTION = K
else
ifeq ($(MAKE_T),$(BINTARGET))
ifeq ($(SBIN_TARGET),_s_)
	# admin 
	DEBSECTION = M
endif
else
	DEBSECTION = L
	DEBPKG = $(shell echo lib$(TARGET) | sed "s/_//g;y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/")
endif
endif

ifeq (_$(HAVEGIT)_,_yes_)
DEBBUILD = $(shell git rev-list HEAD --count)
else
ifeq (_S(HAVESVN)_,_yes_)
DEBBUILD = $(shell svn list -v |sort -n|tail -1|awk '{print $$1}')
else
DEBBUILD = $(shell date +%y%m%d)
endif
endif

DEBUSR = $(DEBRT)/usr
DEBETC = $(DEBRT)/etc
DEBBIN = $(DEBRT)/usr/$(BINDIR_)
DEBLIB = $(DEBRT)/usr/lib
DEBSHARE = $(DEBUSR)/share/$(TARGET)
DEBINC = $(DEBUSR)/include/$(TARGET)
DEBDOC = $(DEBUSR)/share/doc/$(DEBPKG)
DEBMAN = $(DEBUSR)/share/man
DEBCTRL = $(DEBRT)/DEBIAN
DEBMOD = $(DEBRT)/$(KMODDIR)
DEBVERS = $(VERSION)-$(DEBBUILD)

O_DEBPKG = $(OPA)/$(DEBPKG)_$(DEBVERS)_$(MACHINE).deb

$(DEBRT):
	mkdir -m 755 -p ./$@

$(DEBMAN):
	mkdir -m 755 -p ./$@

$(DEBSHARE):
	mkdir -m 755 -p ./$@

$(DEBCTRL):
	mkdir -m 755 -p ./$@
	
$(DEBUSR):
	mkdir -m 755 -p ./$@

$(DEBBIN):
	mkdir -m 755 -p ./$@

ifeq (_$(DEBSECTION)_,_K_)
$(DEBMOD):
	mkdir -m 755 -p ./$@
endif

ifeq (_$(DEBSECTION)_,_L_)
$(DEBLIB):
	mkdir -m 755 -p ./$@

$(DEBINC):
	mkdir -m 755 -p ./$@
endif

$(DEBDOC):
	mkdir -m 755 -p ./$@

contrib/DEBIAN:
	mkdir -m 755 -p ./contrib/DEBIAN

contrib/DEBIAN/control:	debutils
contrib/DEBIAN/copyright:	debutils
contrib/DEBIAN/prerm:	debutils
contrib/DEBIAN/postinst:	debutils

ifeq (_$(isDAEMON)_,_d_)
$(DEBETC)/init.d:
	mkdir -m 755 -p ./$@

contrib/DEBIAN/initd_rc:	debutils

$(DEBETC)/init.d/$(TARGET):	contrib/DEBIAN/initd_rc $(DEBETC)/init.d
	cp contrib/DEBIAN/initd_rc $(DEBETC)/init.d/$(TARGET)
endif

debutils: contrib/DEBIAN
	mkDeb.sh -p $(DEBPKG) -t $(DEBSECTION)

contrib/DEBIAN/changelog: contrib/DEBIAN
ifeq (_$(HAVEGIT)_,_yes_)
	@git log --pretty=format:"- %cd : %s" | awk '{ T = ""; for (i=9; i<NF; i++) {T = T " " $$i}; printf(" - %s %d.%s %d  +%s\n", $$2, $$4, $$3, $$6, T) }' >contrib/DEBIAN/changelog
else
ifeq (_$(HAVESVN)_,_yes_)
	@svn log -v >contrib/DEBIAN/changelog
else
	echo please generate a changelog >contrib/DEBIAN/changelog
endif
endif

ifeq (_$(HAVEGIT)_,_yes_)
contrib/DEBIAN/changelog.Debian: contrib/DEBIAN/changelog
	cp contrib/DEBIAN/changelog contrib/DEBIAN/changelog.Debian
else
contrib/DEBIAN/changelog.Debian: contrib/DEBIAN
ifeq (_$(HAVESVN)_,_yes_)
	@(echo "created by template Makefile";\
	svn ls -v Makefile) >contrib/DEBIAN/changelog.Debian
else
	echo please generate a changelog.Debian >contrib/DEBIAN/changelog.Debian
endif
endif

$(DEBCTRL)/p%: debutils $(DEBCTRL)
#	echo 1 $< 2 $@ 3 $*
	cp contrib/DEBIAN/p$* $@
 
debfiles: $(DEBCTRL)/postinst $(DEBCTRL)/prerm contrib/DEBIAN/changelog contrib/DEBIAN/changelog.Debian
	chmod 755 contrib/DEBIAN/prerm contrib/DEBIAN/postinst	 

ifeq ($(MAKE_T),$(KMOD))
	# kernel module	
install_deb: $(DEBMOD) $(O_KMOD)
	$(INSTALL) -m 755 $(O_KMOD) $(DEBMOD)
else
	# not a kernel module
	
ifeq ($(MAKE_T),$(BINTARGET))
	# binary
DEBDEPLIBS = $(shell ldd $(O_TARGET) | awk '{print $$1}')

install_deb: $(O_TARGET) $(DEBBIN) $(DEBSHARE)
	$(STRIP) -v --strip-unneeded -R .comment $(O_TARGET) -o $(DEBBIN)/$(TARGET)
	chmod 755 $(DEBBIN)/$(TARGET)
	@(if test -d ./share ; then 	\
	  umask 022			;\
	  (cd ./share; $(TAR) --exclude CVS --exclude .svn -cf - .)|(cd $(DEBSHARE); $(TAR) -xf -) ;\
	fi)
else
	# library
DEBDEPLIBS = $(shell ldd $(O_LIBNAME) | awk '{print $$1}')

install_deb: $(DEBLIB) $(DEBINC) $(DEBCTRL) $(O_LIBNAME)
	$(STRIP) -v --strip-unneeded -R .comment $(O_LIBNAME) -o $(DEBLIB)/$(LIBNAME)
	@echo "lib$(TARGET) $(MAJOR) $(DEBDEPEND)" >$(DEBCTRL)/shlibs
	@(cd $(DEBLIB); ln -s $(LIBNAME) $(DEVLIBSYM); ln -s $(LIBNAME) $(SONAME); )
	@(SRCPATH=`pwd` ;\
	  cd $(DEBINC) ; \
	  for I in $(HDRS) ;\
	    do rm -f $$I ;\
	    $(INSTALL) -m 644 $$SRCPATH/$$I $$I ;\
	  done ) 		
endif
#	
## DEBDEPEND = $(shell dpkg-shlibdeps -O $(O_LIBNAME) | cut -f2,3,4,5,6,7,8,9,10,11,12 -d=)
## DEBDEPEND = $(shell mk_shlibs.sh -o $(O_LIBNAME))
#
DEBDEPITEMS = $(shell (for i in $(DEBDEPLIBS); do dpkg -S $$i 2>/dev/null; done) | awk '{print $$1}' | sort -u | cut -f1 -d: | grep -v -- -cross)
DEBDEPEND = $(shell (for item in $(DEBDEPITEMS); do apt-cache show $$item |grep Version:|awk '{printf("%s (>= %s),\n","'$$item'",$$2)}' | sort -u; done) | awk '{printf("%s ",$$0)}' | sed "s/ ,/,/g;s/, $$//g")
#
endif


debclean:
	rm -rf $(DEBRT) contrib/DEBIAN/changelog*

DEBDESCHEAD = $(shell head -1 doc/description)
DEBDESCTAIL = $(shell wc doc/description |awk '{print $$1-1}')

DEBSIZE = $(shell du -s $(DEBRT) | awk '{print $$1}')

ifeq ($(MAKE_T),$(LIBNAME))
debcopy: $(DEBMAN) $(DEBDOC) htmldoc install_deb debfiles $(OPA)/$(TARGET).pc
	mkdir -p $(DEBLIB)/pkgconfig
	cp $(OPA)/$(TARGET).pc $(DEBLIB)/pkgconfig
else
debcopy: $(DEBMAN) $(DEBDOC) htmldoc install_deb debfiles
endif	
	@(if test -d ./man ; then 	\
	  (cd ./man; $(TAR) --exclude CVS --exclude .svn -cf - .)|(cd $(DEBMAN); $(TAR) -xf -) ;\
	  (cd $(DEBMAN); gzip -9 */*);\
	fi)
	@(if test -d ./doc ; then 	\
	  (cd ./doc; $(TAR) --exclude README --exclude description --exclude CVS --exclude .svn -cf - .)|(cd $(DEBDOC); $(TAR) -xf -) ;\
	fi)
	cp contrib/DEBIAN/copyright $(DEBDOC)
	@(cat doc/description; echo ""; cat doc/README) >$(DEBDOC)/README
	gzip -c9 <contrib/DEBIAN/changelog >$(DEBDOC)/changelog.gz
	gzip -c9 <contrib/DEBIAN/changelog.Debian >$(DEBDOC)/changelog.Debian.gz
	@(cd ./$(DEBRT); md5sum `find * -type f|egrep -v DEBIAN/`) >$(DEBCTRL)/md5sums


ifeq ($(MK_DEBIAN_PKG),1)
deb: debclean all debcopy
else
deb: clean debclean all debcopy
endif
	@echo " LIBS: $(DEBDEPLIBS)"
	@echo " ITEMS: $(DEBDEPITEMS)"
	@echo " DEPEND: $(DEBDEPEND)"
	@(echo "Package: $(DEBPKG)";\
	echo "Version: $(DEBVERS)";\
	echo "Depends: $(DEBDEPEND)";\
	echo "Installed-Size: $(DEBSIZE)";\
	sed "s/_ARCH_/$(MACHINE)/g;s/i[3456]86/i386/g;s/_DESC_/$(DEBDESCHEAD)/g" <contrib/DEBIAN/control;\
	tail -$(DEBDESCTAIL) doc/description) >$(DEBCTRL)/control	
	@(find $(DEBRT)/ -type d -empty -exec rmdir {} \; 2>/dev/null; echo "" >/dev/null; )
	chmod -R g-s $(DEBRT)
ifeq ($(MAKE_T),$(LIBNAME))
	find $(DEBRT)/usr/lib -type f -exec chmod 644 {} \;
endif
	fakeroot dpkg-deb --build $(DEBRT)
	lintian $(DEBRT).deb
	mv $(DEBRT).deb $(O_DEBPKG) && $(MAKE) debclean
	

