#!/bin/sh

test_description='git serialized status tests'

. ./test-lib.sh

# This file includes tests for serializing / deserializing
# status data. These tests cover two basic features:
#
# [1] Because users can request different types of untracked-file
#     and ignored file reporting, the cache data generated by
#     serialize must use either the same untracked and ignored
#     parameters as the later deserialize invocation; otherwise,
#     the deserialize invocation must disregard the cached data
#     and run a full scan itself.
#
#     To increase the number of cases where the cached status can
#     be used, we have added a "--untracked-file=complete" option
#     that reports a superset or union of the results from the
#     "-u normal" and "-u all".  We combine this with a filter in
#     deserialize to filter the results.
#
#     Ignored file reporting is simpler in that is an all or
#     nothing; there are no subsets.
#
#     The tests here (in addition to confirming that a cache
#     file can be generated and used by a subsequent status
#     command) need to test this untracked-file filtering.
#
# [2] ensuring the status calls are using data from the status
#     cache as expected.  This includes verifying cached data
#     is used when appropriate as well as falling back to
#     performing a new status scan when the data in the cache
#     is insufficient/known stale.

test_expect_success 'setup' '
	cat >.gitignore <<-\EOF &&
	*.ign
	ignored_dir/
	EOF

	mkdir tracked ignored_dir &&
	touch tracked_1.txt tracked/tracked_1.txt &&
	git add . &&
	test_tick &&
	git commit -m"Adding original file." &&
	mkdir untracked &&
	touch ignored.ign ignored_dir/ignored_2.txt \
	      untracked_1.txt untracked/untracked_2.txt untracked/untracked_3.txt
'

test_expect_success 'verify untracked-files=complete with no conversion' '
	test_when_finished "rm serialized_status.dat new_change.txt output" &&
	cat >expect <<-\EOF &&
	? expect
	? serialized_status.dat
	? untracked/
	? untracked/untracked_2.txt
	? untracked/untracked_3.txt
	? untracked_1.txt
	! ignored.ign
	! ignored_dir/
	EOF
	
	git status --untracked-files=complete --ignored=matching --serialize >serialized_status.dat &&
	touch new_change.txt &&

	git status --porcelain=v2 --untracked-files=complete --ignored=matching --deserialize=serialized_status.dat >output &&
	test_i18ncmp expect output
'

test_expect_success 'verify untracked-files=complete to untracked-files=normal conversion' '
	test_when_finished "rm serialized_status.dat new_change.txt output" &&
	cat >expect <<-\EOF &&
	? expect
	? serialized_status.dat
	? untracked/
	? untracked_1.txt
	EOF
	
	git status --untracked-files=complete --ignored=matching --serialize >serialized_status.dat &&
	touch new_change.txt &&

	git status --porcelain=v2 --deserialize=serialized_status.dat >output &&
	test_i18ncmp expect output
'

test_expect_success 'verify untracked-files=complete to untracked-files=all conversion' '
	test_when_finished "rm serialized_status.dat new_change.txt output" &&
	cat >expect <<-\EOF &&
	? expect
	? serialized_status.dat
	? untracked/untracked_2.txt
	? untracked/untracked_3.txt
	? untracked_1.txt
	! ignored.ign
	! ignored_dir/
	EOF
	
	git status --untracked-files=complete --ignored=matching --serialize >serialized_status.dat &&
	touch new_change.txt &&

	git status --porcelain=v2 --untracked-files=all --ignored=matching --deserialize=serialized_status.dat >output &&
	test_i18ncmp expect output
'

test_expect_success 'verify serialized status with non-convertible ignore mode does new scan' '
	test_when_finished "rm serialized_status.dat new_change.txt output" &&
	cat >expect <<-\EOF &&
	? expect
	? new_change.txt
	? output
	? serialized_status.dat
	? untracked/
	? untracked_1.txt
	! ignored.ign
	! ignored_dir/
	EOF
	
	git status --untracked-files=complete --ignored=matching --serialize >serialized_status.dat &&
	touch new_change.txt &&

	git status --porcelain=v2 --ignored --deserialize=serialized_status.dat >output &&
	test_i18ncmp expect output
'

test_expect_success 'verify serialized status handles path scopes' '
	test_when_finished "rm serialized_status.dat new_change.txt output" &&
	cat >expect <<-\EOF &&
	? untracked/
	EOF
	
	git status --untracked-files=complete --ignored=matching --serialize >serialized_status.dat &&
	touch new_change.txt &&

	git status --porcelain=v2 --deserialize=serialized_status.dat untracked >output &&
	test_i18ncmp expect output
'

test_expect_success 'verify no-ahead-behind and serialized status integration' '
	test_when_finished "rm serialized_status.dat new_change.txt output" &&
	cat >expect <<-\EOF &&
	# branch.oid 68d4a437ea4c2de65800f48c053d4d543b55c410
	# branch.head alt_branch
	# branch.upstream master
	# branch.ab +1 -0
	? expect
	? serialized_status.dat
	? untracked/
	? untracked_1.txt
	EOF

	git checkout -b alt_branch master --track >/dev/null &&
	touch alt_branch_changes.txt &&
	git add alt_branch_changes.txt &&
	test_tick &&
	git commit -m"New commit on alt branch"  &&

	git status --untracked-files=complete --ignored=matching --serialize >serialized_status.dat &&
	touch new_change.txt &&

	git -c status.aheadBehind=false status --porcelain=v2 --branch --ahead-behind --deserialize=serialized_status.dat >output &&
	test_i18ncmp expect output
'

test_done
