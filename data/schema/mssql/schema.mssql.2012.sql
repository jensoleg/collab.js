CREATE DATABASE [collabjs]
GO

USE [collabjs]
GO
/****** Object:  StoredProcedure [dbo].[add_comment]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[add_comment]
	@userId int,
  @postId int,
  @created datetime,
  @content nvarchar(max)
AS
BEGIN
	SET NOCOUNT ON;

  INSERT INTO comments (userId, postId, created, content) 
    values (@userId, @postId, @created, @content);

  SELECT SCOPE_IDENTITY() AS insertId;
END

GO
/****** Object:  StoredProcedure [dbo].[add_post]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[add_post]
	@userId int,
  @content nvarchar(max),
  @created datetime
AS
BEGIN
	SET NOCOUNT ON;

  INSERT INTO posts (userId, content, created) 
    values (@userId, @content, @created);

  SELECT SCOPE_IDENTITY() AS insertId;
END

GO
/****** Object:  StoredProcedure [dbo].[create_account]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[create_account]
  @account nvarchar(50),
  @name nvarchar(50),
  @password varchar(128),
  @email varchar(256),
  @emailHash varchar(32)
AS
BEGIN
  SET NOCOUNT ON;

  INSERT INTO users (account, name, password, email, emailHash)
    values (@account, @name, @password, @email, @emailHash);

  SELECT SCOPE_IDENTITY() AS insertId;
END

GO
/****** Object:  StoredProcedure [dbo].[follow_account]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[follow_account] 
	@originatorId int,
  @targetAccount varchar(50)
AS
BEGIN
	SET NOCOUNT ON;

DECLARE @targetId INT;
SELECT @targetId = u.id FROM users AS u  WHERE u.account = @targetAccount;

IF NOT EXISTS(
	SELECT s.id FROM subscriptions AS s
	  WHERE s.userId = @originatorId AND s.targetUserId = @targetId)
  BEGIN
    INSERT INTO subscriptions (userId, targetUserId) VALUES (@originatorId, @targetId)
  END
END

GO
/****** Object:  StoredProcedure [dbo].[get_account]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_account]
	@account nvarchar(50)
AS
BEGIN
	SET NOCOUNT ON;
  SELECT TOP 1 *, emailHash as pictureId, dbo.get_user_roles(id) AS roles
    FROM users
  WHERE account = @account
END

GO
/****** Object:  StoredProcedure [dbo].[get_account_by_id]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_account_by_id]
	@id int
AS
BEGIN
	SET NOCOUNT ON;
  SELECT TOP 1 *, emailHash as pictureId, dbo.get_user_roles(id) AS roles
    FROM users
  WHERE id = @id
END

GO
/****** Object:  StoredProcedure [dbo].[get_comments]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_comments]
	@postId int
AS
BEGIN
	SET NOCOUNT ON;
  SELECT c.*, u.account, u.name, u.emailHash as pictureId
  FROM comments AS c 
	  LEFT JOIN users AS u ON u.id = c.userId 
  WHERE c.postId = @postId
  ORDER BY created ASC;
END

GO
/****** Object:  StoredProcedure [dbo].[get_followers]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_followers]
	@originatorId int,
  @targetAccount varchar(50),
  @topId int,
  @limit int = 20
AS
BEGIN
	SET NOCOUNT ON;

  DECLARE @targetId INT;
  SELECT @targetId = id FROM users WHERE account = @targetAccount;

  SELECT TOP (@limit) result.* FROM
  (
    SELECT
	    u.id, u.account, u.name, u.website, u.location, u.bio, u.emailHash as pictureId,
      dbo.count_user_posts(u.id) as posts,
	    (SELECT COUNT(id) FROM subscriptions WHERE userId = u.id) AS following,
	    (SELECT COUNT(id) FROM subscriptions WHERE targetUserId = u.id) AS followers,
	    IIF(u.id = @originatorId, CAST(1 as bit), CAST(0 as bit)) AS isOwnProfile,
	    IIF ( 
		    (
			    SELECT COUNT(sub.id) FROM subscriptions AS sub
				    LEFT JOIN users AS usource ON usource.id = sub.userId
				    LEFT JOIN users AS utarget ON utarget.id = sub.targetUserId 
			    WHERE usource.Id = @originatorId AND utarget.account = u.account
			    GROUP BY sub.id
			  ) > 0, CAST(1 as bit), CAST(0 as bit)) AS isFollowed
    FROM subscriptions AS s
	    LEFT JOIN users AS u ON u.id = s.userId
    WHERE s.targetUserId = @targetId 
	    AND EXISTS (select id from users where id = @topId OR @topId = 0)
  ) AS result
  WHERE (@topId <= 0 OR result.id > @topId);
END

GO
/****** Object:  StoredProcedure [dbo].[get_following]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_following]
	@originatorId int,
  @targetAccount varchar(50),
  @topId int,
  @limit int = 20
AS
BEGIN
	SET NOCOUNT ON;

  DECLARE @targetId INT;
  SELECT @targetId = id FROM users WHERE account = @targetAccount;

  SELECT TOP (@limit) result.* FROM
  (
    SELECT
	    u.id, u.account, u.name, u.website, u.location, u.bio, u.emailHash as pictureId,
      dbo.count_user_posts(u.id) as posts,
	    (SELECT COUNT(id) FROM subscriptions WHERE userId = u.id) AS following,
	    (SELECT COUNT(id) FROM subscriptions WHERE targetUserId = u.id) AS followers,
	    IIF(u.id = @originatorId, CAST(1 as bit), CAST(0 as bit)) AS isOwnProfile,
	    IIF ( 
		    (
			    SELECT COUNT(sub.id) FROM subscriptions AS sub
				    LEFT JOIN users AS usource ON usource.id = sub.userId
				    LEFT JOIN users AS utarget ON utarget.id = sub.targetUserId 
			    WHERE usource.Id = @originatorId AND utarget.account = u.account
			    GROUP BY sub.id
			  ) > 0, CAST(1 as bit), CAST(0 as bit)) AS isFollowed
    FROM subscriptions AS s
	    LEFT JOIN users AS u ON u.id = s.targetUserId
    WHERE s.userId = @targetId 
	    AND EXISTS (select id from users where id = @topId OR @topId = 0)
  ) AS result
  WHERE (@topId <= 0 OR result.id > @topId);
END

GO
/****** Object:  StoredProcedure [dbo].[get_main_timeline]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_main_timeline]
  @originatorId int,
  @topId int,
  @limit int = 20
AS
BEGIN
  SET NOCOUNT ON;

  SELECT TOP (@limit) result.* FROM
  (
    SELECT 
      p.*, u.name, u.account, u.emailHash as pictureId,
      dbo.count_post_comments(p.id) as commentsCount
    FROM posts AS p
	    LEFT JOIN users AS u ON u.id = p.userId
    WHERE p.userId IN (
	    SELECT s.targetUserId FROM subscriptions AS s
	    WHERE s.userId = @originatorId AND s.isBlocked = 0
	    UNION SELECT @originatorId
    )
    AND EXISTS (select id from posts where id = @topId OR @topId = 0)
  ) as result
  WHERE (@topId <= 0 OR result.id < @topId)
  ORDER BY result.created DESC
END

GO
/****** Object:  StoredProcedure [dbo].[get_mentions]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_mentions]
	@originatorAccount varchar(50),
  @topId int,
  @limit int = 20
AS
BEGIN
	SET NOCOUNT ON;

  DECLARE @term VARCHAR(51);
  SET @term = CONCAT('%@', @originatorAccount, '%');

  SELECT TOP (@limit) result.* FROM
  (
    SELECT 
      p.*, u.name, u.account, u.emailHash as pictureId,
      dbo.count_post_comments(p.id) as commentsCount
    FROM posts AS p
	    LEFT JOIN users AS u ON u.id = p.userId
    WHERE u.account != @originatorAccount AND p.content LIKE @term
    AND EXISTS (select id from posts where id = @topId OR @topId = 0)
  ) AS result
  WHERE (@topId <= 0 OR result.id < @topId)
  ORDER BY result.created DESC
END

GO
/****** Object:  StoredProcedure [dbo].[get_people]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_people]
	@originatorId int,
  @topId int,
  @limit int = 20
AS
BEGIN
	SET NOCOUNT ON;

  SELECT TOP (@limit) result.* FROM
  (
    SELECT u.id, u.account, u.name, u.website, u.location, u.bio,
      u.created, u.emailHash as pictureId,
      dbo.count_user_posts(u.id) as posts,
	    (SELECT COUNT(id) FROM subscriptions WHERE userId = u.id) AS following,
	    (SELECT COUNT(id) FROM subscriptions WHERE targetUserId = u.id) AS followers,
	    IIF ( 
		    (
			    SELECT COUNT(*) FROM subscriptions AS sub
				    LEFT JOIN users AS usource ON usource.id = sub.userId
				    LEFT JOIN users AS utarget ON utarget.id = sub.targetUserId 
			    WHERE usource.Id = @originatorId AND utarget.account = u.account
			    GROUP BY sub.id
			    ) > 0, CAST(1 as bit), CAST(0 as bit)
	    ) AS isFollowed,
	    IIF(u.id = @originatorId, CAST(1 as bit), CAST(0 as bit)) AS isOwnProfile
    FROM users AS u
    WHERE EXISTS (select id from users where id = @topId OR @topId = 0)
    ) AS result
  WHERE (@topId <= 0 OR result.id > @topId)
  ORDER BY result.created
END

GO
/****** Object:  StoredProcedure [dbo].[get_post]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_post] 
	@postId int
AS
BEGIN
	SET NOCOUNT ON;
  SELECT TOP (1) p.*, u.name, u.account, u.emailHash as pictureId
  FROM posts AS p
	  LEFT JOIN users AS u ON u.id = p.userId
  WHERE p.id = @postId;
END

GO
/****** Object:  StoredProcedure [dbo].[get_post_author]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_post_author]
	@postId int
AS
BEGIN
	SET NOCOUNT ON;

  select TOP (1) u.id, u.account, u.name, u.email, u.emailHash as pictureId
  from posts as p 
    left join users as u on u.id = p.userId 
  where p.id = @postId
END

GO
/****** Object:  StoredProcedure [dbo].[get_public_profile]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_public_profile]
	@caller varchar(50),
  @target varchar(50)
AS
BEGIN
	SET NOCOUNT ON;

  select u.id, u.account, u.name, u.website, u.bio, u.emailHash as pictureId,
      dbo.count_user_posts(u.id) as posts,
		  (select count(id) from subscriptions where userId = u.id) as following,
		  (select count(id) from subscriptions where targetUserId = u.id) as followers,
		  iif ( 
			  (
				  select count(*) 
					  from subscriptions as sub
						  left join users as usource on usource.id = sub.userId
						  left join users as utarget on utarget.id = sub.targetUserId 
					  where usource.account = @caller and utarget.account = u.account
				  group by sub.id
			  ) > 0, CAST(1 as bit), CAST(0 as bit)) as isFollowed
  from users as u
  where u.account = @target
END
GO
/****** Object:  StoredProcedure [dbo].[get_timeline]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_timeline] 
  @targetAccount varchar(50),
  @topId int,
  @limit int = 20
AS
BEGIN
	SET NOCOUNT ON;

  SELECT TOP (@limit) result.* FROM
  (
    SELECT 
      p.*, u.name, u.account, u.emailHash as pictureId,
      dbo.count_post_comments(p.id) as commentsCount
    FROM posts AS p
	    LEFT JOIN users AS u ON u.id = p.userId
    WHERE u.account = @targetAccount
      AND EXISTS (select id from posts where userId = p.userId AND (id = @topId OR @topId = 0))
  ) AS result
  WHERE (@topId <= 0 OR result.id < @topId)
  ORDER BY result.created DESC
END
GO
/****** Object:  StoredProcedure [dbo].[get_timeline_updates]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_timeline_updates] 
	@originatorId int,
  @topId int
AS
BEGIN
	SET NOCOUNT ON;

  SELECT result.* FROM
  (
    SELECT 
      p.*, u.name, u.account, u.emailHash as pictureId,
      dbo.count_post_comments(p.id) as commentsCount
    FROM posts AS p
	    LEFT JOIN users AS u ON u.id = p.userId
    WHERE p.userId IN (
	    SELECT s.targetUserId FROM subscriptions AS s
	    WHERE s.userId = @originatorId AND s.isBlocked = 0
	    UNION SELECT @originatorId
    )
  ) as result
  WHERE result.id > @topId AND @topId > 0
  ORDER BY result.created ASC;
END
GO
/****** Object:  StoredProcedure [dbo].[get_timeline_updates_count]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[get_timeline_updates_count]
	@originatorId int,
  @topId int
AS
BEGIN
	SET NOCOUNT ON;

  SELECT COUNT(id) AS posts FROM (
    SELECT p.id
    FROM posts as p
    WHERE p.userId IN (
      SELECT s.targetUserId FROM subscriptions as s
      WHERE s.userId = @originatorId AND s.isBlocked = 0
      UNION SELECT @originatorId
      )
  ) as result
  WHERE id > @topId AND @topId > 0
END
GO
/****** Object:  StoredProcedure [dbo].[unfollow_account]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[unfollow_account] 
	@originatorId int,
  @targetAccount varchar(50)
AS
BEGIN
	SET NOCOUNT ON;

  DECLARE @targetId INT;
  SELECT @targetId = u.id FROM users AS u  WHERE u.account = @targetAccount;

  DELETE FROM subscriptions WHERE userId = @originatorId AND targetUserId = @targetId;
END
GO
/****** Object:  UserDefinedFunction [dbo].[count_post_comments]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[count_post_comments]
(
	@postId int
)
RETURNS int
AS
BEGIN
	DECLARE @result int;
  SELECT @result = COUNT(id) FROM comments WHERE postId = @postId;
	RETURN @result;
END
GO
/****** Object:  UserDefinedFunction [dbo].[count_subscriptions_user]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[count_subscriptions_user] 
(
	@userId int
)
RETURNS int
AS
BEGIN
	DECLARE @result int;
	SELECT @result = COUNT(id) FROM subscriptions WHERE userId = @userId;
	RETURN @result;
END
GO
/****** Object:  UserDefinedFunction [dbo].[count_user_posts]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[count_user_posts] 
(
	@userId int
)
RETURNS int
AS
BEGIN
  DECLARE @result int
  SELECT @result = COUNT(id) FROM posts WHERE userId = @userId
	RETURN @result;
END
GO
/****** Object:  UserDefinedFunction [dbo].[get_user_roles]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[get_user_roles] 
(
	@userId int
)
RETURNS nvarchar(max)
AS
BEGIN
  DECLARE @result nvarchar(max)

  SELECT @result = COALESCE(@result + ',','') + r.loweredName
  FROM roles as r, user_roles as ur
  WHERE r.id = ur.roleId AND ur.userId = @userId
  ORDER BY r.loweredName;

	RETURN COALESCE(@result, '');
END
GO
/****** Object:  Table [dbo].[comments]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[comments](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[userId] [int] NOT NULL,
	[postId] [int] NOT NULL,
	[created] [datetime] NOT NULL,
	[content] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_comments] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[posts]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[posts](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[userId] [int] NOT NULL,
	[content] [nvarchar](max) NOT NULL,
	[created] [datetime] NOT NULL,
 CONSTRAINT [PK_posts] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[roles]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[roles](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](256) NOT NULL,
	[loweredName] [nvarchar](256) NOT NULL,
 CONSTRAINT [PK_roles] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[subscriptions]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[subscriptions](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[userId] [int] NOT NULL,
	[targetUserId] [int] NOT NULL,
	[isBlocked] [bit] NOT NULL,
 CONSTRAINT [PK_subscriptions] PRIMARY KEY CLUSTERED 
(
	[userId] ASC,
	[targetUserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[user_roles]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[user_roles](
	[userId] [int] NOT NULL,
	[roleId] [int] NOT NULL,
 CONSTRAINT [PK_user_role] PRIMARY KEY CLUSTERED 
(
	[userId] ASC,
	[roleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[users]    Script Date: 2/25/2013 8:19:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[users](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[account] [varchar](50) NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[created] [datetime] NOT NULL,
	[password] [varchar](128) NOT NULL,
	[email] [varchar](256) NOT NULL,
	[emailHash] [varchar](32) NOT NULL,
	[location] [nvarchar](50) NULL,
	[website] [nvarchar](256) NULL,
	[bio] [nvarchar](160) NULL,
 CONSTRAINT [PK_id] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Index [IX_subscriptions_id]    Script Date: 2/25/2013 8:19:50 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_subscriptions_id] ON [dbo].[subscriptions]
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [ix_role]    Script Date: 2/25/2013 8:19:50 PM ******/
CREATE NONCLUSTERED INDEX [ix_role] ON [dbo].[user_roles]
(
	[roleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_account]    Script Date: 2/25/2013 8:19:50 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_account] ON [dbo].[users]
(
	[account] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[comments] ADD  CONSTRAINT [DF_comments_created]  DEFAULT (getutcdate()) FOR [created]
GO
ALTER TABLE [dbo].[posts] ADD  CONSTRAINT [DF_posts_created]  DEFAULT (getutcdate()) FOR [created]
GO
ALTER TABLE [dbo].[subscriptions] ADD  CONSTRAINT [DF_subscriptions_isBlocked]  DEFAULT ((0)) FOR [isBlocked]
GO
ALTER TABLE [dbo].[users] ADD  CONSTRAINT [DF_users_created] DEFAULT (getutcdate()) FOR [created]
GO
ALTER TABLE [dbo].[users] ADD  CONSTRAINT [DF_users_emailHash] DEFAULT ('00000000000000000000000000000000') FOR [emailHash]
GO
ALTER TABLE [dbo].[comments]  WITH CHECK ADD  CONSTRAINT [FK_comments_post] FOREIGN KEY([postId])
REFERENCES [dbo].[posts] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[comments] CHECK CONSTRAINT [FK_comments_post]
GO
ALTER TABLE [dbo].[comments]  WITH CHECK ADD  CONSTRAINT [FK_comments_user] FOREIGN KEY([userId])
REFERENCES [dbo].[users] ([id])
GO
ALTER TABLE [dbo].[comments] CHECK CONSTRAINT [FK_comments_user]
GO
ALTER TABLE [dbo].[posts]  WITH CHECK ADD  CONSTRAINT [FK_posts_user] FOREIGN KEY([userId])
REFERENCES [dbo].[users] ([id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[posts] CHECK CONSTRAINT [FK_posts_user]
GO
ALTER TABLE [dbo].[subscriptions]  WITH CHECK ADD  CONSTRAINT [FK_subscriptions_targetUserId] FOREIGN KEY([targetUserId])
REFERENCES [dbo].[users] ([id])
GO
ALTER TABLE [dbo].[subscriptions] CHECK CONSTRAINT [FK_subscriptions_targetUserId]
GO
ALTER TABLE [dbo].[subscriptions]  WITH CHECK ADD  CONSTRAINT [FK_subscriptions_userId] FOREIGN KEY([userId])
REFERENCES [dbo].[users] ([id])
GO
ALTER TABLE [dbo].[subscriptions] CHECK CONSTRAINT [FK_subscriptions_userId]
GO
ALTER TABLE [dbo].[user_roles]  WITH CHECK ADD  CONSTRAINT [FK_ur_role] FOREIGN KEY([roleId])
REFERENCES [dbo].[roles] ([id])
GO
ALTER TABLE [dbo].[user_roles] CHECK CONSTRAINT [FK_ur_role]
GO
ALTER TABLE [dbo].[user_roles]  WITH CHECK ADD  CONSTRAINT [FK_ur_user] FOREIGN KEY([userId])
REFERENCES [dbo].[users] ([id])
GO
ALTER TABLE [dbo].[user_roles] CHECK CONSTRAINT [FK_ur_user]
GO

-- v0.2.0

CREATE PROCEDURE get_posts_by_hashtag
  @query nvarchar(256),
  @topId int,
  @limit int = 20
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @hashtag VARCHAR(256);
  SET @hashtag = '%' + @query + '%';

  SELECT TOP (@limit) result.* FROM
  (
    SELECT
      p.*, u.name, u.account, u.emailHash as pictureId,
      dbo.count_post_comments(p.id) as commentsCount
    FROM posts AS p
	    LEFT JOIN users AS u ON u.id = p.userId
    WHERE p.content LIKE @hashtag
    AND EXISTS (select id from posts where id = @topId OR @topId = 0)
  ) AS result
  WHERE (@topId <= 0 OR result.id < @topId)
  ORDER BY result.created DESC
END
GO

IF NOT EXISTS (SELECT TOP 1 id from roles where loweredName = 'administrator')
BEGIN
  INSERT INTO roles (name, loweredName) VALUES ('Administrator', 'administrator')
END
GO