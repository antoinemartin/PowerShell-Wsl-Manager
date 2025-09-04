INSERT INTO
    [ImageSource] (
        [Id],
        [Name],
        [TAGS],
        [Url],
        [Type],
        [Configured],
        [Username],
        [Uid],
        [Distribution],
        [Release],
        [LocalFilename],
        [DigestSource],
        [DigestAlgorithm],
        [DigestUrl],
        [Digest]
    )
VALUES
    (
        :Id,
        :Name,
        :TAGS,
        :Url,
        :Type,
        :Configured,
        :Username,
        :Uid,
        :Distribution,
        :Release,
        :LocalFilename,
        :DigestSource,
        :DigestAlgorithm,
        :DigestUrl,
        :Digest
    ) ON CONFLICT ([Type], [Configured], [Distribution], [Release]) DO
UPDATE
SET
    [Name] = excluded.[Name],
    [TAGS] = excluded.[TAGS],
    [Url] = excluded.[Url],
    [Username] = excluded.[Username],
    [Uid] = excluded.[Uid],
    [LocalFilename] = excluded.[LocalFilename],
    [DigestSource] = excluded.[DigestSource],
    [DigestAlgorithm] = excluded.[DigestAlgorithm],
    [DigestUrl] = excluded.[DigestUrl],
    [Digest] = excluded.[Digest],
    [UpdateDate] = CURRENT_TIMESTAMP
