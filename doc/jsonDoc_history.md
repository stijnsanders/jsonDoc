# How jsonDoc came to be

On a quest to know more about the different database solutions that are out there, I decided to get to know [MongoDB](https://www.mongodb.com/) better by creating my own _really basic_ connector to get data in to and out of a MongoDB server.

I was convinced, in accordance to the new [NoSQL](https://en.wikipedia.org/wiki/NoSQL) way of working, it would make little sense to try to marry the existing system of data-aware components to a full fledged MongoDB data provider, because it would never fit exactly right. Even only because it would require the developer to put up a fixed schema on beforehand on a system that has a flexible schema as one of its strong points.

Also, the [xxm](http://yoy.be/xxm/) project was well under way, and was very much resembling the early days of [PHP](https://php.net), where the platform was very stable, but no big known PHP frameworks have grown to maturity yet. In xxm projects that still heavily depend on the server-side logic being written out in the files that stand for the dynamic web-pages, it would fit just fine to have a MongoDB query take place there and get its results converted to the required HTML output.

So I started on [TMongoWire](https://github.com/stijnsanders/TMongoWire) and created `IBSONDocument` to both handle the [BSON](http://bsonspec.org/) data MongoDB uses for storage and transfer, _and_ allow access to the structure and values of the document itself.

I really _(really!)_ dislike long lists of overloads in components like database connectors for every thinkable type you could use, and always remember fondly the days of ODBC and ADO that have a very basic solution to this problem, which Delphi also supports with the `Variant` and `OleVariant` types. Sadly enough `Variant`-typed variables have a bad reputation, and are said to be clumsy and slow. It is true that you could get into situations where passing variants forces the system to make deep copies of big chunks of data just to throw them away a moment later, but with proper care and understanding these side-effects can be avoided. Handled correctly, variants perform as smoothly as the Delphi string system or reference counting on interfaces.

When, in later endeavours, I came across the requirement to handle JSON documents, the logical next step was to re-use what I had and create `IJSONDocument` on the same base but with parsing and constructing actual JSON strings instead of BSON data. Finally, some time after _jsonDoc_ was proven production-ready, I switched TMongoWire over to _jsonDoc_ and separate BSON-to/from-JSON converters.

This MongoDB heritage explains why a collection of key/value pairs is called a _document_ here.