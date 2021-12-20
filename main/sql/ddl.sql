create table project
(
    id   integer      not null,
    name varchar(255) not null,

    constraint project_PK primary key (id)
);

create table branch
(
    id         integer      not null,
    name       varchar(255) not null,
    project_id integer      not null,

    constraint branch_PK primary key (id),
    constraint branch_K1 unique (name, project_id),
    constraint branch_FK foreign key (project_id) references project (id)
);

create table "user"
(
    id            integer     not null,
    username      varchar(31) not null,
    password_hash text        not null,

    constraint user_PK primary key (id),
    constraint user_K1 unique (username)
);

create table pull_request
(
    id             integer not null,
    branch_from_id integer not null,
    branch_to_id   integer not null,
    project_id     integer not null,
    author_id      integer not null,

    constraint pull_request_PK primary key (id),
    constraint pull_request_FK1 foreign key (branch_from_id) references branch (id),
    constraint pull_request_FK2 foreign key (branch_to_id) references branch (id),
    constraint pull_request_FK3 foreign key (project_id) references project (id),
    constraint pull_request_FK4 foreign key (author_id) references "user" (id)
);

create type task_status as enum ('resolved', 'not resolved');

create table task
(
    id              integer       not null,
    description     varchar(1023) not null,
    status          task_status   not null,
    pull_request_id integer       not null,
    author_id       integer       not null,

    constraint task_PK primary key (id),
    constraint task_FK1 foreign key (pull_request_id) references pull_request (id),
    constraint task_FK2 foreign key (author_id) references "user" (id)
);

create table comment
(
    id              integer       not null,
    content         varchar(1023) not null,
    created_at      timestamp     not null,
    is_deleted      boolean       not null,
    reply_to_id     integer,
    pull_request_id integer       not null,
    author_id       integer       not null,

    constraint comment_PK primary key (id),
    constraint comment_FK1 foreign key (reply_to_id) references comment (id),
    constraint comment_FK2 foreign key (pull_request_id) references pull_request (id),
    constraint comment_FK3 foreign key (author_id) references "user" (id)
);

create type reviewer_status as enum ('approved', 'requested changes', 'no action');

create table reviewer
(
    pull_request_id integer         not null,
    user_id         integer         not null,
    status          reviewer_status not null,

    constraint reviewer_PK primary key (pull_request_id, user_id),
    constraint reviewer_FK1 foreign key (pull_request_id) references pull_request (id),
    constraint reviewer_FK2 foreign key (user_id) references "user" (id)
);

create table committed_merge
(
    pull_request_id integer   not null,
    merged_by_id    integer   not null,
    merged_at       timestamp not null,

    constraint committed_merge_PK primary key (pull_request_id),
    constraint committed_merge_FK1 foreign key (pull_request_id) references pull_request (id),
    constraint committed_merge_FK2 foreign key (merged_by_id) references "user" (id)
);

create table user_project_access
(
    project_id integer not null,
    user_id    integer not null,

    constraint user_project_access_PK primary key (project_id, user_id),
    constraint user_project_access_FK1 foreign key (project_id) references project (id),
    constraint user_project_access_FK2 foreign key (user_id) references "user" (id)
);

-- pull request from a branch to itself has no sense
alter table pull_request
    add check (branch_from_id <> branch_to_id);

create function getBranchProject(
    branch_id integer
) returns integer as
'
    select project_id
    from branch
    where branch_id = id;
' language sql;

alter table pull_request
    add check (
                project_id = getBranchProject(branch_from_id) and
                project_id = getBranchProject(branch_to_id)
        );

create function getCommentCreatedTime(
    comment_id integer
) returns timestamp as
'
    select created_at
    from comment
    where comment_id = id;
' language sql;

alter table comment
    add check (reply_to_id is null or created_at > getCommentCreatedTime(reply_to_id));
