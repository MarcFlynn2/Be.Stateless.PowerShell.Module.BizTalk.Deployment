﻿#region Copyright & License

// Copyright © 2012 - 2022 François Chabot
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#endregion

using Be.Stateless.BizTalk.Dsl.Binding;
using Be.Stateless.BizTalk.Dsl.Binding.Adapter;
using Be.Stateless.BizTalk.MicroPipelines;

namespace Be.Stateless.BizTalk.Dummies.Bindings
{
	internal class TestApplication : ApplicationBinding
	{
		public TestApplication()
		{
			Name = nameof(TestApplication);
			ReferencedApplications.Add(new TestReferencedApplication());
			ReceivePorts.Add(new OneWayReceivePort(), new TwoWayReceivePort());
			SendPorts.Add(new OneWaySendPort(), new TwoWaySendPort());
		}
	}

	internal class OneWayReceivePort : ReceivePort
	{
		public OneWayReceivePort()
		{
			Name = nameof(OneWayReceivePort);
			ReceiveLocations.Add(new OneWayReceiveLocation());
		}
	}

	internal class OneWayReceiveLocation : ReceiveLocation
	{
		public OneWayReceiveLocation()
		{
			Name = nameof(OneWayReceiveLocation);
			ReceivePipeline = new ReceivePipeline<PassThruReceive>();
			Transport.Adapter = new FileAdapter.Inbound(a => { a.ReceiveFolder = @"c:\file"; });
			Transport.Host = "Rx_Host_File";
		}
	}

	internal class TwoWayReceivePort : ReceivePort
	{
		public TwoWayReceivePort()
		{
			Name = nameof(TwoWayReceivePort);
			ReceiveLocations.Add(new TwoWayReceiveLocation());
		}
	}

	internal class TwoWayReceiveLocation : ReceiveLocation
	{
		public TwoWayReceiveLocation()
		{
			Name = nameof(TwoWayReceiveLocation);
			ReceivePipeline = new ReceivePipeline<PassThruReceive>();
			SendPipeline = new SendPipeline<PassThruTransmit>();
			Transport.Adapter = new FileAdapter.Inbound(a => { a.ReceiveFolder = @"c:\file"; });
			Transport.Host = "Rx_Host_File";
		}
	}

	internal class OneWaySendPort : SendPort
	{
		public OneWaySendPort()
		{
			Name = nameof(OneWaySendPort);
			SendPipeline = new SendPipeline<PassThruTransmit>();
			Transport.Adapter = new FileAdapter.Outbound(a => { a.DestinationFolder = @"c:\file"; });
			Transport.Host = "Tx_Host_File";
		}
	}

	internal class TwoWaySendPort : SendPort
	{
		public TwoWaySendPort()
		{
			Name = nameof(TwoWaySendPort);
			SendPipeline = new SendPipeline<PassThruTransmit>();
			ReceivePipeline = new ReceivePipeline<PassThruReceive>();
			Transport.Adapter = new FileAdapter.Outbound(a => { a.DestinationFolder = @"c:\file"; });
			Transport.Host = "Tx_Host_File";
		}
	}
}
