package trading.snapshots

import trading.core.snapshots.{ SnapshotReader, SnapshotWriter }
import trading.core.{ AppTopic, EventSource }
import trading.events.TradeEvent
import trading.lib.Consumer
import trading.lib.inject.circeBytesInject
import trading.state.TradeState

import cats.effect.*
import dev.profunktor.pulsar.{ Config, Pulsar, Subscription }
import dev.profunktor.redis4cats.Redis
import dev.profunktor.redis4cats.effect.Log.Stdout.*
import fs2.Stream

object Main extends IOApp.Simple:
  def run: IO[Unit] =
    Stream
      .resource(resources)
      .flatMap { case (consumer, reader, writer) =>
        Stream
          .eval(reader.latest.map(_.getOrElse(TradeState.empty)))
          .evalTap(latest => IO.println(s">>> SNAPSHOTS: $latest"))
          .flatMap { latest =>
            consumer.receive
              .mapAccumulate(latest) { case (st, evt) =>
                EventSource.runS(st)(evt.command) -> ()
              }
              .map(_._1)
              .evalMap { st =>
                IO.println(s"Saving snapshot: $st") >> writer.save(st)
              }
          }
      }
      .compile
      .drain

  val config = Config.Builder.default

  val topic = AppTopic.TradingEvents.make(config)

  // Failover subscription (it's enough to deploy two instances)
  val sub =
    Subscription.Builder
      .withName("snapshots-sub")
      .withType(Subscription.Type.Failover)
      .build

  def resources =
    for {
      pulsar <- Pulsar.make[IO](config.url)
      _      <- Resource.eval(IO.println(">>> Initializing snapshots service <<<"))
      redis  <- Redis[IO].utf8("redis://localhost")
      reader = SnapshotReader.fromClient(redis)
      writer = SnapshotWriter.fromClient(redis)
      consumer <- Consumer.pulsar[IO, TradeEvent](pulsar, topic, sub)
    } yield (consumer, reader, writer)
