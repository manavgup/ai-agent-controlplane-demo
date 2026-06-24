"""Room voter agent executor.

Reads the vote prompt from the user message, computes a vote with the pure
decide_vote() logic, and returns it as a single text artifact. The stance and
expense travel inside the prompt, so this agent holds no per-voter state — one
process backs all five fixed catalog entries.
"""

from a2a.helpers import (
    get_message_text,
    new_task_from_user_message,
    new_text_message,
    new_text_part,
)
from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.server.tasks import TaskUpdater
from a2a.types.a2a_pb2 import TaskState

from vote import decide_vote


class RoomVoterExecutor(AgentExecutor):
    """A2A executor: turns a vote prompt into 'VOTE=approve|reject :: reason'."""

    async def execute(
        self,
        context: RequestContext,
        event_queue: EventQueue,
    ) -> None:
        if context.current_task:
            task = context.current_task
        else:
            task = new_task_from_user_message(context.message)
            await event_queue.enqueue_event(task)

        task_updater = TaskUpdater(
            event_queue=event_queue, task_id=task.id, context_id=task.context_id
        )
        await task_updater.update_status(
            state=TaskState.TASK_STATE_WORKING,
            message=new_text_message("Voting on expense..."),
        )

        query = get_message_text(context.message) or ""
        result = decide_vote(query)
        print("Room voter result:", result)

        await task_updater.add_artifact(
            parts=[new_text_part(text=result, media_type="text/plain")]
        )
        await task_updater.update_status(
            state=TaskState.TASK_STATE_COMPLETED,
            message=new_text_message("Vote complete."),
        )

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError("Cancel is not supported.")
