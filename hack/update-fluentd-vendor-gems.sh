#!/bin/bash
# Update the vendored-in fluentd gems
# - get the latest fluentd gem and latest dependencies
# - unpack the gems into the fluentd/vendor directory

set -euxo pipefail

basedir=$( dirname $0 )
if [ -z "$basedir" ] ; then
    pushd .. > /dev/null
    basedir=$( pwd )
    popd
else
    pushd $basedir/.. > /dev/null
    basedir=$( pwd )
    popd > /dev/null
fi

fluentddir=$basedir/fluentd

gemlist=$( mktemp )
manifest=$( mktemp )
trap "rm -f $gemlist $manifest" EXIT
# the format of gem install --explain is
# name-of-gem-file-X.Y.Z - we assume everything
# after the last '-' is the version, and split
# the output into name version
gem install --explain -g $fluentddir/Gemfile | \
sed -e '/^Gems/d' -e 's,[-]\([^-][^-]*\)$, \1,' | sort > $gemlist
while read gemname gemver ; do
    vendordir=$fluentddir/vendored_gem_src/$gemname
    gemfile=${gemname}-${gemver}.gem
    gemlink=$fluentddir/vendored_gem_src/${gemname}-${gemver}
    gem fetch $gemname --version $gemver
    rm -rf $vendordir
    mkdir -p $vendordir
    # gem unpack always creates $gemname-$gemver
    # but we want to unpack in $gemname
    # so create a symlink to fool unpack
    rm -f $gemlink
    ln -s $vendordir $gemlink
    gem unpack $gemfile --target $fluentddir/vendored_gem_src
    # the .gitignore files cause no end of trouble
    # - the files in the gem should not be ignored, but in
    #   _many_ cases, files are listed both in the gem _and_
    #   in the .gitignore
    # - many gemspecs use `git ls-files` to get the list of
    #   files to include in the gem - the .gitignore in many
    #   cases will exclude files which should be in the gem
    find $vendordir -name .gitignore -exec rm -f {} \;
    # some gems do not include the gemspec in the data, so unpack
    # won't see it - but we need the gemspec for gem build later
    if [ ! -f $vendordir/$gemname.gemspec ] ; then
        gem spec -l --ruby $gemfile > $vendordir/$gemname.gemspec
    fi
    homepage=$( gem spec $gemfile homepage | awk '{print $2}' )
    if [ -z "$homepage" ] ; then
        echo ERROR: gem $gemfile has no homepage
        grep github.com $vendordir/$gemname.gemspec
        exit 1
    fi
    if type -p brew > /dev/null 2>&1 ; then
        if [ $gemname = fluentd ] ; then
            pkgname=fluentd
        else
            pkgname="rubygem-${gemname}"
        fi
        if foundname=$( brew search package --exact $pkgname ) && [ "$foundname" = "$pkgname" ] ; then
            : # package exists in brew
        else
            pkgname=$gemname
        fi
    fi
    echo $pkgname $gemver $homepage >> $manifest
    rm -f $gemlink $gemfile
done < $gemlist
rm -f $gemlist
# jemalloc
. $fluentddir/source.jemalloc
jemalloc=$( mktemp )
trap "rm -f $jemalloc" EXIT
curl -s -L -o $jemalloc $JEMALLOC_SOURCE
sum=$( sha512sum $jemalloc | awk '{print $1}' )
if [ "$sum" != "$JEMALLOC_SHA512SUM" ] ; then
    echo ERROR: sha512sum of $jemalloc is not correct
    echo expected $JEMALLOC_SHA512SUM
    echo actual $sum
fi
pushd $fluentddir > /dev/null
rm -rf jemalloc
tar xfj $jemalloc
mv jemalloc-$JEMALLOC_VER jemalloc
popd > /dev/null
rm -f $jemalloc
echo jemalloc $JEMALLOC_VER $JEMALLOC_SOURCE >> $manifest
sort $manifest > $fluentddir/rh-manifest.txt
