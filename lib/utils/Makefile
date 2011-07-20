BUILDS=cpu-hogs
TARGETS=all clean

$(TARGETS):
	for b in $(BUILDS) ; do $(MAKE) -C $$b $@ ; done
	@echo Success

$(BUILDS):
	for t in $(TARGETS) ; do $(MAKE) -C $@ $$t ; done
	@echo Success
