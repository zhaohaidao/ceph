#!/bin/bash -ex

NUM_OSDS=$(./bin/ceph osd dump -f json | jq '.osds | length')

# Check that BZBD is initially disabled
for (( i=0; i<$NUM_OSDS; i++ ))
do
        SETTING=$(./bin/ceph config get osd.$i bluestore_zero_block_detection)
        if [ $SETTING != "false" ]; then
                echo "BZBD shouldn't be enabled at this point."
                exit 1
        fi
done

# Create a test pool "foo" (bluestore_zero_block_detection=false)
./bin/ceph osd pool create foo

# Check utilization after creating "foo" (bluestore_zero_block_detection=false)
sleep 15
SIZE_0=$(./bin/rados df -f json | jq '.pools[] | select(.name=="foo").size_kb')
if [ $SIZE_0 -ne 0 ]; then
	echo "Pool should be empty since it was just created."
	exit 1
fi

# Make a directory for test files
mkdir ~/bluestore_zero_block_detection_test_files

# Write a non-zero object to pool "foo" (bluestore_zero_block_detection=false)
head -c 10 /dev/random > ~/bluestore_zero_block_detection_test_files/random_data
./bin/rados -p foo put random_data ~/bluestore_zero_block_detection_test_files/random_data

# Check utilization after writing a random object (bluestore_zero_block_detection=false)
sleep 15
SIZE_1=$(./bin/rados df -f json | jq '.pools[] | select(.name=="foo").size_kb')
if [ $SIZE_1 -le $SIZE_0 ]; then
        echo "Pool should be filled since we wrote a non-zero object."
        exit 1
fi

# Write a zero object to pool "foo" (bluestore_zero_block_detection=false)
head -c 10 /dev/zero > ~/bluestore_zero_block_detection_test_files/zero_data
./bin/rados -p foo put zero_data ~/bluestore_zero_block_detection_test_files/zero_data

# Check utilization after writing a zero object (bluestore_zero_block_detection=false)
sleep 15
SIZE_2=$(./bin/rados df -f json | jq '.pools[] | select(.name=="foo").size_kb')
if [ $SIZE_2 -le $SIZE_1 ]; then
        echo "Pool should be filled since BZBD is disabled."
        exit 1
fi

# Enable bluestore_zero_block_detection on all OSDs
for (( i=0; i<NUM_OSDS; i++ ))
do
	./bin/ceph config set osd.$i bluestore_zero_block_detection true
done

# Check that the config is set correctly
for (( i=0; i<NUM_OSDS; i++ ))
do
	SETTING=$(./bin/ceph config get osd.$i bluestore_zero_block_detection)
	if [ $SETTING != "true" ]; then
		echo "BZBD setting did not apply correctly."
		exit 1
	fi
done

# Write a non-zero object to pool "foo" (bluestore_zero_block_detection=true)
./bin/rados -p foo put random_data_2 ~/bluestore_zero_block_detection_test_files/random_data

# Check utilization after writing a random object (bluestore_zero_block_detection=true)
sleep 15
SIZE_3=$(./bin/rados df -f json | jq '.pools[] | select(.name=="foo").size_kb')
if [ $SIZE_3 -le $SIZE_2 ]; then
        echo "Pool should be filled more since we wrote a non-zero object."
        exit 1
fi

# Write a zero object to pool "foo" (bluestore_zero_block_detection=true)
./bin/rados -p foo put zero_data_2 ~/bluestore_zero_block_detection_test_files/zero_data

# Check utilization after writing a zero object (bluestore_zero_block_detection=true)
sleep 15
SIZE_4=$(./bin/rados df -f json | jq '.pools[] | select(.name=="foo").size_kb')
if [ $SIZE_4 -ne $SIZE_3 ]; then
        echo "Pool should not have changed sinze BZBD is enabled."
        exit 1
fi

# Test on a larger zeroed object (bluestore_zero_block_detection=true)
head -c 10000 /dev/zero > ~/bluestore_zero_block_detection_test_files/zero_data_big
./bin/rados -p foo put zero_data_3 ~/bluestore_zero_block_detection_test_files/zero_data_big

# Check utilization after writing a large zero object (bluestore_zero_block_detection=true)
sleep 15
SIZE_5=$(./bin/rados df -f json | jq '.pools[] | select(.name=="foo").size_kb')
if [ $SIZE_5 -ne $SIZE_4 ]; then
        echo "Pool should not have changed sinze BZBD is enabled."
        exit 1
fi

# Listing the objects from pool "foo", we can see a total of 5 objects that we created,
# two of which were skipped due to bluestore_zero_block_detection.
NUM_OBJECTS=$( ./bin/rados -p foo ls -f json | jq '. | length')
if [ $NUM_OBJECTS -ne 5 ]; then
	echo "Incorrect amount of objects."
	exit 1
fi

# Remove test file directory
rm -rf ~/bluestore_zero_block_detection_test_files
