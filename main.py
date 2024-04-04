import discord
from discord.ext import commands
import random
from bot_logic import get_class

intents = discord.Intents.all()

bot = commands.Bot(command_prefix='/', intents=intents)


@bot.command()
async def meme_at(cxt):
    secim=random.choice(["memes/TR1a7e888c7a1d59220c4a7e866c083ae8.jpg","memes/TRmem3.jpg","memes/TR1y5bql.png","memes/images.png","memes/1234.jpg","memes/D030564E-1E13-46C7-A8AE-3C1293B9913B.jpg"])
    f=open(secim,"rb")
    file=discord.File(f)
    await cxt.send(file=file)
@bot.command()
async def komutlar(ctx):
    await ctx.send("/meme_at(size rastgele meme göderir")
    await ctx.send("(incele(gönderdiğiniz resimdeki kişinin cinsiyetini söyler")               
@bot.command()
async def incele(ctx):
    await ctx.send('Algılama başladı!')
    if ctx.message.attachments:
        await ctx.send("Resim bulundu")
        for attachment in ctx.message.attachments:

            file_name = attachment.filename

            file_path = f"kaydedilenler/{file_name}"

            await attachment.save(file_path)
            await ctx.send("Resim Kaydedildi!")

            class_name, score= get_class("keras_model.h5","labels.txt",file_path)

            await ctx.send(f"Bu bir: {class_name}. Bundan {score} kadar eminim")
    else:
        await ctx.send("Lütfen bir resim yükleyin!")


bot.run("MTE2MzE1NTAwNzY0Njk5ODYyOA.G7L_mN.-_-gIch-QWBAJiu9SQnkJj-wEgfKKkl_d3dbE0")
