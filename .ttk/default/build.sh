#!/bin/bash

source ttk.inc.sh

langs=$(which_langs $*)
log_info "Processing languages '$langs'"

function update_source() {
	log_info "Updating '$SOURCE_DIR'"
	if [ ! -d $SOURCE_DIR/.svn ]; then
		svn co $svnverbosity $MOZREPONAME/projects/mozilla.com/trunk/locales/en-GB $SOURCE_DIR
	else
		svn up $svnverbosity $SOURCE_DIR
	fi
}

log_info "Updating first level of '$TARGET_DIR'"
if [ ! -d $TARGET_DIR/.svn ]; then
	svn co $svnverbosity --depth=files $MOZREPONAME/projects/mozilla.com/trunk/locales/ $TARGET_DIR
else
	svn up $svnverbosity --depth=files $TARGET_DIR
fi

for lang in $langs
do
	log_info "Processing language '$lang'"
	polang=$(get_language_pootle $lang)
	if [ "$polang" == "templates" ]; then
		update_source
		rm -rf $POT_DIR
		mkdir -p $POT_DIR/templates/mozorg/emails
		(cd $SOURCE_DIR 
		moz2po --errorlevel=$errorlevel --progress=$progress . $POT_DIR
		txt2po --errorlevel=$errorlevel --progress=$progress templates/mozorg/emails $POT_DIR/templates/mozorg/emails
		)
		podebug --errorlevel=$errorlevel --progress=$progress --rewrite=blank $POT_DIR $POT_DIR
		rename -f 's/\.po$/.pot/' $(find $POT_DIR -name "*.po")
		rm $POT_DIR/templates/mozorg/emails/*.txt  # Cleanup files that moz2po copied
	else
		mozlang=$(get_language_upstream $lang)
		verbose "Migrate - update PO files to new POT files"
		tempdir=`mktemp -d tmp.XXXXXXXXXX`
		if [ -d ${PO_DIR}/${polang} ]; then
			cp -R ${PO_DIR}/${polang} ${tempdir}/${polang}
			(cd ${PO_DIR}/${polang}; rm $(find . -type f -name "*.po"))
		fi
		pomigrate2 --use-compendium --pot2po $pomigrate2verbosity ${tempdir}/${polang} ${PO_DIR}/${polang} ${POT_DIR}
		# FIXME we should revert stuff that wasn't part of this migration e.g. mobile
		rm -rf ${tempdir}

		clean_po_location $PO_DIR $polang
		revert_unchanged_po_git $PO_DIR $polang

		svn revert $svnverbosity -R $TARGET_DIR/$mozlang
		svn up $svnverbosity $TARGET_DIR/$mozlang
		rm -f $(find $TARGET_DIR/$mozlang -name "*.lang")
		po2moz --errorlevel=$errorlevel --progress=$progress -t $SOURCE_DIR $PO_DIR/$polang $TARGET_DIR/$mozlang
		mkdir -p $TARGET_DIR/$mozlang/templates/mozorg/emails
		po2txt --errorlevel=$errorlevel --progress=$progress -t $SOURCE_DIR/templates/mozorg/emails $PO_DIR/$polang/templates/mozorg/emails $TARGET_DIR/$mozlang/templates/mozorg/emails
	fi
done