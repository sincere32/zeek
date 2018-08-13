# @TEST-SERIALIZE: comm
#
# @TEST-EXEC: btest-bg-run manager-1 BROPATH=$BROPATH:.. CLUSTER_NODE=manager-1 bro %INPUT
# @TEST-EXEC: btest-bg-run worker-1  BROPATH=$BROPATH:.. CLUSTER_NODE=worker-1 bro %INPUT
# @TEST-EXEC: btest-bg-run worker-2  BROPATH=$BROPATH:.. CLUSTER_NODE=worker-2 bro %INPUT
# @TEST-EXEC: btest-bg-wait 20

# @TEST-EXEC: btest-diff manager-1/weird_stats.log

@TEST-START-FILE cluster-layout.bro
redef Cluster::nodes = {
	["manager-1"] = [$node_type=Cluster::MANAGER, $ip=127.0.0.1, $p=37757/tcp],
	["worker-1"]  = [$node_type=Cluster::WORKER,  $ip=127.0.0.1, $p=37760/tcp, $manager="manager-1", $interface="eth0"],
	["worker-2"]  = [$node_type=Cluster::WORKER,  $ip=127.0.0.1, $p=37761/tcp, $manager="manager-1", $interface="eth1"],
};
@TEST-END-FILE

@load misc/weird-stats

redef Cluster::retry_interval = 1sec;
redef Broker::default_listen_retry = 1sec;
redef Broker::default_connect_retry = 1sec;

redef Log::enable_local_logging = T;
redef Log::default_rotation_interval = 0secs;
redef WeirdStats::weird_stat_interval = 5secs;

event terminate_me()
	{
	terminate();
	}

event Broker::peer_lost(endpoint: Broker::EndpointInfo, msg: string)
	{
	terminate();
	}

event ready_again()
	{
	Reporter::net_weird("weird1");

	if ( Cluster::node == "worker-2" )
		{
		schedule 5secs { terminate_me() };
		}
	}

event ready_for_data()
	{
	local n = 0;

	if ( Cluster::node == "worker-1" )
		{
		while ( n < 1000 )
			{
			Reporter::net_weird("weird1");
			++n;
			}

		Reporter::net_weird("weird3");
		}
	else if ( Cluster::node == "worker-2" )
		{
		while ( n < 1000 )
			{
			Reporter::net_weird("weird1");
			Reporter::net_weird("weird2");
			++n;
			}
		}

	schedule 5secs { ready_again() };
	}


@if ( Cluster::local_node_type() == Cluster::MANAGER )

event bro_init()
	{
	Broker::auto_publish(Cluster::worker_topic, ready_for_data);
	}

global peer_count = 0;

event Broker::peer_added(endpoint: Broker::EndpointInfo, msg: string)
	{
	++peer_count;

	if ( peer_count == 2 )
		event ready_for_data();
	}

@endif