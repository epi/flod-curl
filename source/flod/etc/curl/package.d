module flod.etc.curl;

import flod.traits : satisfies, isPushSource;

@satisfies!(isPushSource, CurlReader)
private struct CurlReader(Sink) {
	Sink sink;

	import etc.c.curl;
	import std.exception : enforce;
	import std.string : toStringz;

	const(char)* url;
	Throwable e;

	this()(auto ref Sink sink, string url)
	{
		import flod.meta : moveIfNonCopyable;
		this.sink = moveIfNonCopyable(sink);
		this.url = url.toStringz();
	}

	private extern(C)
	static size_t mywrite(const(void)* buf, size_t ms, size_t nm, void* obj)
	{
		CurlReader* self = cast(CurlReader*) obj;
		size_t written;
		try {
			written = self.sink.push((cast(const(ubyte)*) buf)[0 .. ms * nm]);
		} catch (Throwable e) {
			self.e = e;
		}
		return written;
	}

	void run()
	{
		CURL* curl = enforce(curl_easy_init(), "failed to init curl");
		curl_easy_setopt(curl, CurlOption.url, url);
		curl_easy_setopt(curl, CurlOption.writefunction, &mywrite);
		curl_easy_setopt(curl, CurlOption.file, &this);
		auto err = curl_easy_perform(curl);
		if (err != CurlError.ok)
		curl_easy_cleanup(curl);
		if (e)
			throw e;
	}
}

unittest {
	import std.file : write, remove;
	import std.uuid : randomUUID;
	import flod.pipeline;
	struct PushSink {
		size_t push(T)(const(T)[] buf) { return buf.length; }
	}
	auto name = "unittest-" ~ randomUUID().toString();
	write(name, new ubyte[1048576]);
	scope(exit) remove(name);
	download("file:///etc/passwd").pipe!PushSink.run();
}

auto download(string url)
{
	import flod.pipeline;
	static assert(isPipeline!(typeof(pipe!CurlReader(url))));
	return pipe!CurlReader(url);
}
