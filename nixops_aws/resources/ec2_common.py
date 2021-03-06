from __future__ import annotations
import socket
import getpass

import boto3
import nixops.util
import nixops.deployment
import nixops.resources
import nixops_aws.ec2_utils
from nixops.state import StateDict
from typing import Optional
from boto.ec2.connection import EC2Connection
from typing import Mapping, TYPE_CHECKING

if TYPE_CHECKING:
    import mypy_boto3_ec2


class EC2CommonState:
    depl: nixops.deployment.Deployment
    name: str
    _state: StateDict
    _client: Optional["mypy_boto3_ec2.EC2Client"]

    # Not always available
    _conn: Optional[EC2Connection]
    access_key_id: Optional[str]

    COMMON_EC2_RESERVED = ["accessKeyId", "ec2.tags"]

    def _retry(self, fun, **kwargs):
        return nixops_aws.ec2_utils.retry(fun, logger=self, **kwargs)

    tags = nixops.util.attr_property("ec2.tags", {}, "json")

    def get_common_tags(self) -> Mapping[str, str]:
        tags = {
            "CharonNetworkUUID": self.depl.uuid,
            "CharonMachineName": self.name,
            "CharonStateFile": "{0}@{1}:{2}".format(
                getpass.getuser(), socket.gethostname(), self.depl._db.db_file
            ),
        }
        if self.depl.name:
            tags["CharonNetworkName"] = self.depl.name
        return tags

    def get_default_name_tag(self):
        return "{0} [{1}]".format(self.depl.description, self.name)

    def update_tags_using(self, updater, user_tags={}, check=False):
        tags = {"Name": self.get_default_name_tag()}
        tags.update(user_tags)
        tags.update(self.get_common_tags())

        if tags != self.tags or check:
            updater(tags)
            self.tags = tags

    def update_tags(self, id, user_tags={}, check=False):
        def updater(tags):
            # FIXME: handle removing tags.
            if self._conn is None:
                raise Exception("bug: self._conn is None")
            self._retry(lambda: self._conn.create_tags([id], tags))

        self.update_tags_using(updater, user_tags=user_tags, check=check)

    def get_client(self):
        """
        Generic method to get a cached EC2 AWS client or create it.
        """

        # Here be dragons!
        # This class is weird and doesn't have it's full dependencies declared.
        # This function will _only_ work when _also_ inheriting from DiffEngineResourceState
        new_access_key_id = (
            self.get_defn().config.accessKeyId if self.depl.definitions else None  # type: ignore
        ) or nixops_aws.ec2_utils.get_access_key_id()
        if new_access_key_id is not None:
            self.access_key_id = new_access_key_id
        if self.access_key_id is None:
            raise Exception(
                "please set 'accessKeyId', $EC2_ACCESS_KEY or $AWS_ACCESS_KEY_ID"
            )
        if hasattr(self, "_client"):
            if self._client:
                return self._client
        assert self._state["region"]
        region: str = str(self._state["region"])
        (access_key_id, secret_access_key) = nixops_aws.ec2_utils.fetch_aws_secret_key(
            self.access_key_id
        )
        self._client: "mypy_boto3_ec2.EC2Client" = boto3.session.Session().client(
            service_name="ec2",
            region_name=region,
            aws_access_key_id=access_key_id,
            aws_secret_access_key=secret_access_key,
        )
        return self._client

    def reset_client(self):
        self._client = None
